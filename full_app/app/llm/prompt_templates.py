class PromptTemplates:

    @staticmethod
    def demo_generation_prompt(use_case: str, complexity: str):

        return f"""
You are a system simulator.

Generate a realistic distributed system simulation.

Rules:
- Output ONLY valid JSON
- No explanations
- No markdown

Use case: {use_case}
Complexity: {complexity}

Return format:
{{
  "components": [],
  "logs": [],
  "insights": []
}}

Make logs realistic and failure-aware.
"""
