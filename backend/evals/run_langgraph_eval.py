#!/usr/bin/env python3
"""
LangSmith Evaluation Runner for Stemly's Parallel LangGraph Architecture.

Supports:
1. Local Evaluation Mode: Zero external credentials needed; benchmarks accuracy, pedagogy, and latency.
2. Cloud LangSmith Mode: If LANGCHAIN_API_KEY is configured, uploads traces and runs live dashboard evals.

Usage:
    python evals/run_langgraph_eval.py
    python evals/run_langgraph_eval.py --cloud
"""

import argparse
import asyncio
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

from config import settings
from evals.agent_evaluators import (
    eval_followup_quality,
    eval_latency_sla,
    eval_math_accuracy,
    eval_pedagogy_socratic,
    eval_simulation_action,
    langsmith_followup_evaluator,
    langsmith_math_evaluator,
    langsmith_pedagogy_evaluator,
    langsmith_simulation_evaluator,
)
from services.agents import run_orchestrated_tutor

DATASET_FILE = CURRENT_DIR / "agent_eval_dataset.json"


def load_dataset() -> List[Dict[str, Any]]:
    """Loads benchmark test cases from JSON dataset."""
    if not DATASET_FILE.exists():
        raise FileNotFoundError(f"Dataset file not found at: {DATASET_FILE}")
    with open(DATASET_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


async def run_single_example(example: Dict[str, Any]) -> Dict[str, Any]:
    """Runs a single test case through the LangGraph agent pipeline and measures latency."""
    inputs = example["inputs"]
    expected = example["expected_outputs"]

    t0 = time.perf_counter()
    outputs = await run_orchestrated_tutor(
        query=inputs["query"],
        topic=inputs["topic"],
        student_id=f"eval_{example['id']}",
    )
    t1 = time.perf_counter()
    duration_ms = (t1 - t0) * 1000.0

    # Execute all evaluators
    score_math = eval_math_accuracy(outputs, expected)
    score_pedagogy = eval_pedagogy_socratic(outputs, expected)
    score_sim = eval_simulation_action(outputs, expected)
    score_chips = eval_followup_quality(outputs)
    score_latency = eval_latency_sla(duration_ms)

    return {
        "id": example["id"],
        "duration_ms": duration_ms,
        "math_score": score_math["score"],
        "pedagogy_score": score_pedagogy["score"],
        "sim_score": score_sim["score"],
        "chips_score": score_chips["score"],
        "latency_score": score_latency["score"],
        "overall_pass": all(s >= 1.0 for s in [score_math["score"], score_pedagogy["score"], score_sim["score"], score_chips["score"]]),
    }


async def run_local_evaluation(dataset: List[Dict[str, Any]]):
    """Executes full evaluation suite locally and prints structured scorecard."""
    print("=" * 80)
    print("🔬 RUNNING STEMLY LANGGRAPH EVALUATION BENCHMARK")
    print(f"Dataset: {len(dataset)} examples | Model: {settings.GROQ_TEXT_MODEL}")
    print("=" * 80)

    results = []
    for ex in dataset:
        print(f"Evaluating {ex['id']}... ", end="", flush=True)
        res = await run_single_example(ex)
        results.append(res)
        status = "PASSED" if res["overall_pass"] else "FAILED"
        print(f"[{status}] in {round(res['duration_ms'], 1)}ms")

    # Aggregate Metrics
    total = len(results)
    passed_count = sum(1 for r in results if r["overall_pass"])
    avg_latency = sum(r["duration_ms"] for r in results) / total
    avg_math = (sum(r["math_score"] for r in results) / total) * 100.0
    avg_pedagogy = (sum(r["pedagogy_score"] for r in results) / total) * 100.0
    avg_sim = (sum(r["sim_score"] for r in results) / total) * 100.0
    avg_chips = (sum(r["chips_score"] for r in results) / total) * 100.0

    print("\n" + "=" * 80)
    print("📊 LANGSMITH EVALUATION SCORECARD")
    print("=" * 80)
    print(f"Overall Pass Rate:             {passed_count}/{total} ({round((passed_count/total)*100, 1)}%)")
    print(f"Math Calculation Accuracy:     {round(avg_math, 1)}%")
    print(f"Socratic Pedagogy Accuracy:    {round(avg_pedagogy, 1)}%")
    print(f"Simulation Clamping & Action:  {round(avg_sim, 1)}%")
    print(f"Follow-up Question Quality:    {round(avg_chips, 1)}%")
    print(f"Average Execution Latency:     {round(avg_latency, 1)}ms")
    print("=" * 80)

    if passed_count < total:
        print("❌ Evaluation threshold failed! Inspect failures above.")
        return 1
    else:
        print("✅ ALL EVALUATION BENCHMARKS PASSED PERFECTLY!")
        return 0


def run_cloud_evaluation(dataset: List[Dict[str, Any]]):
    """Executes evaluation using official LangSmith Cloud Client and uploads results."""
    api_key = settings.LANGCHAIN_API_KEY or os.environ.get("LANGCHAIN_API_KEY")
    if not api_key:
        print("⚠️  No LANGCHAIN_API_KEY configured. Please set LANGCHAIN_API_KEY to run Cloud LangSmith Evals.")
        print("Falling back to local benchmark evaluation...\n")
        return asyncio.run(run_local_evaluation(dataset))

    os.environ["LANGCHAIN_TRACING_V2"] = "true"
    os.environ["LANGCHAIN_API_KEY"] = api_key
    os.environ["LANGCHAIN_PROJECT"] = settings.LANGCHAIN_PROJECT

    from langsmith import Client, evaluate

    client = Client()
    dataset_name = "stemly-langgraph-benchmark"

    # Sync dataset to LangSmith
    if not client.has_dataset(dataset_name=dataset_name):
        ds = client.create_dataset(dataset_name=dataset_name, description="STEM Multi-Agent Physics & Math Benchmark")
        for ex in dataset:
            client.create_example(
                inputs=ex["inputs"],
                outputs={"expected_outputs": ex["expected_outputs"]},
                dataset_id=ds.id,
            )
        print(f"✅ Created LangSmith dataset: {dataset_name}")
    else:
        print(f"ℹ️  Using existing LangSmith dataset: {dataset_name}")

    def target_fn(inputs: Dict[str, Any]) -> Dict[str, Any]:
        return asyncio.run(
            run_orchestrated_tutor(
                query=inputs["query"],
                topic=inputs["topic"],
                student_id="langsmith_eval_cloud",
            )
        )

    print("🚀 Triggering LangSmith Cloud Evaluation experiment...")
    eval_results = evaluate(
        target_fn,
        data=dataset_name,
        evaluators=[
            langsmith_math_evaluator,
            langsmith_pedagogy_evaluator,
            langsmith_simulation_evaluator,
            langsmith_followup_evaluator,
        ],
        experiment_prefix="stemly-parallel-langgraph",
        max_concurrency=2,
    )

    print("\n🎉 LangSmith Cloud Experiment completed!")
    print(f"🔗 View Dashboard: https://smith.langchain.com/o/default/projects/p/{settings.LANGCHAIN_PROJECT}")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Stemly LangSmith Evaluation Runner")
    parser.add_argument("--cloud", action="store_true", help="Run via LangSmith Cloud Client")
    args = parser.parse_args()

    dataset = load_dataset()

    if args.cloud:
        exit_code = run_cloud_evaluation(dataset)
    else:
        exit_code = asyncio.run(run_local_evaluation(dataset))

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
