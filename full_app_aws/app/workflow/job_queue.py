import os
import boto3


class JobQueue:

    def __init__(self, queue_name=None):
        resolved_queue_name = queue_name or os.getenv("GENAI_QUEUE_NAME")
        region_name = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")

        if not resolved_queue_name:
            raise ValueError("GENAI_QUEUE_NAME environment variable is required")

        if not region_name:
            raise ValueError("AWS_REGION or AWS_DEFAULT_REGION environment variable is required")

        self.queue_name = resolved_queue_name
        sqs_client = boto3.client("sqs", region_name=region_name)
        
        # Get queue URL from queue name
        response = sqs_client.get_queue_url(QueueName=self.queue_name)
        self.queue_url = response["QueueUrl"]
        self.sqs = sqs_client

    def push(self, job_id: str):
        """Send job_id to SQS queue"""
        self.sqs.send_message(
            QueueUrl=self.queue_url,
            MessageBody=job_id
        )

    def pop(self):
        """Receive one message from SQS queue without deleting it."""
        response = self.sqs.receive_message(
            QueueUrl=self.queue_url,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=10
        )

        messages = response.get("Messages", [])

        if not messages:
            return None

        message = messages[0]
        return {
            "job_id": message["Body"],
            "receipt_handle": message["ReceiptHandle"]
        }

    def ack(self, receipt_handle: str):
        """Delete a processed message from SQS queue."""
        self.sqs.delete_message(
            QueueUrl=self.queue_url,
            ReceiptHandle=receipt_handle
        )
