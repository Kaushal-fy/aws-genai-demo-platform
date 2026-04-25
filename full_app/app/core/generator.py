from app.core.observability import log


class DemoGenerator:

    def generate(self, use_case: str, complexity: str):

        log("generator_start", {
            "use_case": use_case,
            "complexity": complexity
        })

        components = [
            "API Gateway",
            "Auth Service",
            "Payment Service",
            "Database"
        ]

        logs = [
            f"{use_case}: service initialized",
            f"{use_case}: request received"
        ]

        insights = [
            "Latency observed in downstream service"
        ]

        if complexity == "high":
            logs.append("cascade failure detected")
            insights.append("system-wide degradation observed")

        log("generator_complete", {
            "components": len(components),
            "logs": len(logs),
            "insights": len(insights)
        })

        return {
            "components": components,
            "logs": logs,
            "insights": insights
        }"insights": insights
        }
