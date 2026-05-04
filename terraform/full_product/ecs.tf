resource "null_resource" "worker_image" {
  count = var.prebuilt_worker_image_uri == null && var.build_worker_image ? 1 : 0

  triggers = {
    repository_url = aws_ecr_repository.worker.repository_url
    image_tag      = var.worker_image_tag
    source_hash = sha256(join("", [
      for file_path in local.worker_source_files : filemd5("${local.app_source_dir}/${file_path}")
    ]))
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", aws_ecr_repository.worker.repository_url)[0]}
      docker build -f ${local.app_source_dir}/Dockerfile.worker -t ${aws_ecr_repository.worker.repository_url}:${var.worker_image_tag} ${local.app_source_dir}
      docker push ${aws_ecr_repository.worker.repository_url}:${var.worker_image_tag}
    EOT
  }
}

resource "aws_ecs_cluster" "main" {
  name = local.worker_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "worker" {
  family                   = local.worker_service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.worker_cpu)
  memory                   = tostring(var.worker_memory)
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = local.worker_image_uri
      essential = true
      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "GENAI_JOBS_TABLE", value = aws_dynamodb_table.jobs.name },
        { name = "GENAI_QUEUE_NAME", value = aws_sqs_queue.jobs.name },
        { name = "GENAI_S3_BUCKET", value = aws_s3_bucket.artifacts.bucket },
        { name = "GENAI_METADATA_TABLE", value = aws_dynamodb_table.metadata.name },
        { name = "GENAI_USE_BEDROCK", value = tostring(var.enable_bedrock_runtime) },
        { name = "BEDROCK_MODEL_ID", value = var.bedrock_model_id },
        { name = "AWS_XRAY_DAEMON_ADDRESS", value = "127.0.0.1:2000" },
        { name = "APPCONFIG_APPLICATION_ID", value = aws_appconfig_application.main.id },
        { name = "APPCONFIG_ENVIRONMENT_ID", value = aws_appconfig_environment.main.environment_id },
        { name = "APPCONFIG_CONFIGURATION_PROFILE_ID", value = aws_appconfig_configuration_profile.runtime.configuration_profile_id }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_worker.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "worker"
        }
      }
      dependsOn = [
        {
          containerName = "xray-daemon"
          condition     = "START"
        }
      ]
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:3.3.3"
      essential = false
      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_worker.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "xray"
        }
      }
    }
  ])

  depends_on = [null_resource.worker_image]
}

resource "aws_ecs_service" "worker" {
  name            = local.worker_service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.worker.id]
    assign_public_ip = true
  }

  depends_on = [null_resource.worker_image]
}

resource "aws_appautoscaling_target" "worker" {
  max_capacity       = var.worker_max_capacity
  min_capacity       = var.worker_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "worker_cpu" {
  name               = "${local.worker_service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}