import random


class DemoGenerator:

    def generate(self, use_case: str, complexity: str):

        base_components = [
            "API Gateway",
            "Auth Service",
            "Payment Service",
            "Database"
        ]

        logs = [
            f"{use_case}: service initialized",
            f"{use_case}: request received",
            f"{use_case}: processing started"
        ]

        insights = [
            "Latency observed in downstream service",
            "Retry mechanism triggered"
        ]

        if complexity == "high":
            logs.append("cascade failure detected")
            insights.append("system-wide degradation observed")

        # simulate randomness (future GenAI placeholder behavior)
        if random.random() > 0.7:
            insights.append("unexpected spike in traffic detected")

        return {
            "components": base_components,
            "logs": logs,
            "insights": insights
        }
