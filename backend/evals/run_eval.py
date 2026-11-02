#!/usr/bin/env python3
"""
Manual Vision & Topic Classification Evaluation Script for Stemly.

IMPORTANT:
This script performs live calls against the real Groq Vision API.
DO NOT RUN IN CI. Run manually for model quality benchmarking and regression checks.

Usage:
    python evals/run_eval.py [--api-key YOUR_GROQ_KEY] [--model llama-3.2-11b-vision-preview]
"""

import argparse
import asyncio
import io
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List

# Ensure backend root is on sys.path
CURRENT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = CURRENT_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from PIL import Image, ImageDraw  # noqa: E402

from config import settings  # noqa: E402
from services.llm.client import llm_clients  # noqa: E402
from services.llm.vision import TopicAnalysis, analyze_image  # noqa: E402


def generate_synthetic_problem_image(title: str, text: str) -> bytes:
    """
    Renders the STEM problem statement onto a clean white canvas
    to simulate a scanned question paper or digital worksheet.
    """
    img = Image.new("RGB", (800, 450), color=(255, 255, 255))
    draw = ImageDraw.Draw(img)

    # Decorative header banner
    draw.rectangle([(0, 0), (800, 50)], fill=(33, 150, 243))
    draw.text((20, 15), f"STEM Problem: {title}", fill=(255, 255, 255))

    # Border
    draw.rectangle([(5, 5), (795, 445)], outline=(200, 200, 200), width=2)

    # Word wrap problem text
    words = text.split()
    lines: List[str] = []
    current_line: List[str] = []
    for word in words:
        current_line.append(word)
        if len(" ".join(current_line)) > 70:
            lines.append(" ".join(current_line))
            current_line = []
    if current_line:
        lines.append(" ".join(current_line))

    y_pos = 90
    for line in lines[:10]:
        draw.text((30, y_pos), line, fill=(20, 20, 20))
        y_pos += 30

    output = io.BytesIO()
    img.save(output, format="JPEG", quality=90)
    return output.getvalue()


def is_topic_match(predicted: str, expected: str) -> bool:
    """
    Evaluates whether predicted topic is semantically equivalent to expected topic.
    Handles synonyms and sub-specialties.
    """
    p = predicted.strip().lower()
    e = expected.strip().lower()

    if p == e or e in p or p in e:
        return True

    # Equivalence clusters
    synonyms = {
        "projectile motion": ["projectile", "2d kinematics", "kinematics", "mechanics"],
        "kinematics": ["motion", "1d kinematics", "mechanics", "free fall"],
        "optics": ["ray optics", "geometrical optics", "light", "lenses"],
        "waves": ["simple harmonic motion", "shm", "oscillations", "wave motion"],
        "electricity": ["current electricity", "circuits", "electromagnetism"],
        "magnetism": ["magnetic fields", "electromagnetism"],
        "thermodynamics": ["thermal physics", "heat and thermodynamics", "gas laws"],
        "mechanics": ["newtonian mechanics", "classical mechanics", "dynamics"],
        "calculus": ["differentiation", "derivatives", "integration"],
        "algebra": ["algebraic equations", "polynomials"],
        "chemistry": ["physical chemistry", "general chemistry"],
        "biology": ["cell biology", "biochemistry", "plant biology"],
    }

    if e in synonyms:
        if any(syn in p for syn in synonyms[e]):
            return True

    return False


async def run_evaluation(api_key: str, model_name: str, dataset_path: Path):
    if not api_key:
        print("\n[ERROR] GROQ_VISION_API_KEY is required to run live evaluation.")
        print("Pass via --api-key <KEY> or set GROQ_VISION_API_KEY in your environment/.env\n")
        sys.exit(1)

    # Configure live settings
    settings.GROQ_VISION_API_KEY = api_key
    settings.GROQ_VISION_MODEL = model_name
    settings.TESTING = False

    # Start live async HTTP clients
    await llm_clients.start()

    with open(dataset_path, "r", encoding="utf-8") as f:
        dataset = json.load(f)

    print("\n================================================================================")
    print("STEMLY VISION & TOPIC EVALUATION SUITE")
    print(f"Model: {model_name} | Dataset: {dataset_path.name} ({len(dataset)} samples)")
    print("================================================================================\n")

    results: List[Dict[str, Any]] = []
    correct_topics = 0
    valid_json_count = 0
    total_latency_ms = 0.0

    header_fmt = "{:<12} | {:<12} | {:<20} | {:<20} | {:<6} | {:<7} | {:<8}"
    print(header_fmt.format("ID", "Domain", "Expected", "Predicted", "Match", "Valid", "Time(s)"))
    print("-" * 95)

    for item in dataset:
        item_id = item["id"]
        domain = item.get("domain", "General")
        expected_topic = item["expected_topic"]
        problem_text = item["problem_text"]

        image_bytes = generate_synthetic_problem_image(expected_topic, problem_text)

        start_time = time.perf_counter()
        is_valid_json = False
        predicted_topic = "N/A"
        is_match = False
        degraded = False

        try:
            analysis: TopicAnalysis = await analyze_image(
                image_bytes=image_bytes,
                ocr_text=problem_text,
            )
            elapsed_sec = time.perf_counter() - start_time
            total_latency_ms += elapsed_sec * 1000.0

            # Pydantic schema validation check
            if isinstance(analysis, TopicAnalysis):
                is_valid_json = True
                valid_json_count += 1

            predicted_topic = analysis.topic
            degraded = analysis.degraded

            if not degraded and is_topic_match(predicted_topic, expected_topic):
                is_match = True
                correct_topics += 1

        except Exception as exc:
            elapsed_sec = time.perf_counter() - start_time
            predicted_topic = f"Error: {exc.__class__.__name__}"

        status_match = "PASS" if is_match else "FAIL"
        status_json = "YES" if is_valid_json else "NO"
        print(
            header_fmt.format(
                item_id,
                domain[:12],
                expected_topic[:20],
                predicted_topic[:20],
                status_match,
                status_json,
                f"{elapsed_sec:.2f}",
            )
        )

        results.append(
            {
                "id": item_id,
                "domain": domain,
                "expected_topic": expected_topic,
                "predicted_topic": predicted_topic,
                "match": is_match,
                "valid_json": is_valid_json,
                "degraded": degraded,
                "latency_sec": round(elapsed_sec, 3),
            }
        )

    # Close clients
    await llm_clients.close()

    total_samples = len(dataset)
    accuracy_pct = (correct_topics / total_samples) * 100 if total_samples else 0
    validity_pct = (valid_json_count / total_samples) * 100 if total_samples else 0
    avg_latency_ms = total_latency_ms / total_samples if total_samples else 0

    print("-" * 95)
    print("\nBENCHMARK SUMMARY:")
    print(f"Total Samples Evaluated:    {total_samples}")
    print(f"Topic Classification Acc:  {accuracy_pct:.1f}% ({correct_topics}/{total_samples})")
    print(f"JSON / Schema Validity:    {validity_pct:.1f}% ({valid_json_count}/{total_samples})")
    print(f"Mean Latency Per Sample:   {avg_latency_ms:.0f} ms")
    print(f"Target Accuracy (>=85%):   {'PASSED' if accuracy_pct >= 85 else 'BELOW TARGET'}")
    print(f"Target Validity (100%):    {'PASSED' if validity_pct == 100 else 'BELOW TARGET'}\n")

    output_file = CURRENT_DIR / "eval_results.json"
    with open(output_file, "w", encoding="utf-8") as out:
        json.dump(
            {
                "timestamp": time.time(),
                "model": model_name,
                "total_samples": total_samples,
                "accuracy_percent": round(accuracy_pct, 2),
                "validity_percent": round(validity_pct, 2),
                "avg_latency_ms": round(avg_latency_ms, 1),
                "results": results,
            },
            out,
            indent=2,
        )
    print(f"Detailed run artifact saved to: {output_file}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Run STEM topic classification accuracy and schema validity evaluation against real Groq Vision."
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("GROQ_VISION_API_KEY", ""),
        help="Groq API key for Vision model (default: reads from GROQ_VISION_API_KEY env)",
    )
    parser.add_argument(
        "--model",
        default=settings.GROQ_VISION_MODEL or "llama-3.2-11b-vision-preview",
        help="Groq Vision model identifier to evaluate",
    )
    parser.add_argument(
        "--dataset",
        default=str(CURRENT_DIR / "dataset.json"),
        help="Path to evaluation dataset JSON file",
    )
    args = parser.parse_args()

    asyncio.run(
        run_evaluation(
            api_key=args.api_key,
            model_name=args.model,
            dataset_path=Path(args.dataset),
        )
    )


if __name__ == "__main__":
    main()
