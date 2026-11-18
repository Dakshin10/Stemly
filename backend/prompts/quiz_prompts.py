"""
Versioned Prompts for Multiple-Choice Quiz Generation.
"""

QUIZ_GENERATION_PROMPT_V1 = """You are an expert STEM examiner and professor.
Generate high-quality multiple choice questions (MCQs) for the topic: {topic}.

Requirements:
- Create EXACTLY {num_questions} questions.
- Difficulty level: {difficulty} (if easy: emphasize direct concepts and definitions; if medium: combine concepts with standard problem-solving; if hard: challenge with multi-step derivations and edge cases).
- Balance conceptual understanding and numerical reasoning.
- Every question must have EXACTLY 4 plausible options (index 0, 1, 2, 3).
- Provide correct_index (an integer from 0 to 3).
- Provide a clear, pedagogical explanation for why the answer is correct and why other options are incorrect.
- Provide a concise one-line takeaway summarizing the core principle.

Output Format:
You MUST respond ONLY with a valid JSON object matching this schema:
{{
  "topic": "{topic}",
  "difficulty": "{difficulty}",
  "questions": [
    {{
      "question": "Question text here",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_index": 0,
      "explanation": "Detailed explanation of the correct answer and reasoning.",
      "takeaway": "Key one-line principle to remember."
    }}
  ]
}}
Do NOT include markdown fences, backticks, or text outside the JSON object.
"""
