import json

from app.workflow.job_actions import get_async_job, submit_async_job


def _response(status_code: int, body: dict):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }


def _load_body(event):
    body = event.get("body")

    if body is None:
        return {}

    if isinstance(body, dict):
        return body

    return json.loads(body)


def submit_demo_handler(event, context):
    try:
        payload = _load_body(event)
    except json.JSONDecodeError:
        return _response(400, {"error": "Request body must be valid JSON"})

    use_case = payload.get("use_case")
    complexity = payload.get("complexity")

    if not use_case or not complexity:
        return _response(400, {"error": "use_case and complexity are required"})

    result = submit_async_job(use_case, complexity)
    return _response(200, result)


def get_job_handler(event, context):
    path_parameters = event.get("pathParameters") or {}
    job_id = path_parameters.get("job_id")

    if not job_id:
        return _response(400, {"error": "job_id path parameter is required"})

    result = get_async_job(job_id)

    if not result:
        return _response(404, {"error": "job not found", "job_id": job_id})

    return _response(200, result)


def api_gateway_router(event, context):
    request_context = event.get("requestContext") or {}
    http_context = request_context.get("http") or {}

    method = http_context.get("method") or event.get("httpMethod")
    path = event.get("rawPath") or event.get("path") or ""

    if method == "POST" and path.endswith("/generate-demo-async"):
        return submit_demo_handler(event, context)

    if method == "GET" and "/job/" in path:
        return get_job_handler(event, context)

    return _response(404, {"error": "route not found", "method": method, "path": path})