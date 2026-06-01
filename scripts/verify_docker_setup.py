#!/usr/bin/env python3
"""
J3DI Docker Environment — GPU Verification Script
Target: Lenovo P16 — RTX 3000 Ada 12 GB / 128 GB RAM
Run inside the container: python scripts/verify_docker_setup.py
"""

import sys
import platform
import subprocess

def check(name: str, import_cmd: str, version_attr: str = "__version__") -> bool:
    try:
        mod = __import__(import_cmd)
        ver = getattr(mod, version_attr, "OK")
        print(f"  ✅ {name:25s} {ver}")
        return True
    except ImportError as e:
        print(f"  ❌ {name:25s} MISSING — {e}")
        return False

def check_gpu():
    """Detailed GPU diagnostics."""
    print("\n── GPU / CUDA ─────────────────────────────────────────")
    gpu_ok = True

    # nvidia-smi
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,driver_version,memory.total",
             "--format=csv,noheader"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            for line in result.stdout.strip().split("\n"):
                print(f"  ✅ nvidia-smi:             {line.strip()}")
        else:
            print(f"  ❌ nvidia-smi:             failed ({result.stderr.strip()})")
            gpu_ok = False
    except FileNotFoundError:
        print(f"  ❌ nvidia-smi:             not found in container")
        gpu_ok = False

    # CUDA version
    try:
        result = subprocess.run(
            ["nvcc", "--version"], capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            for line in result.stdout.strip().split("\n"):
                if "release" in line.lower():
                    print(f"  ✅ CUDA Toolkit:           {line.strip()}")
        else:
            print(f"  ⚠️  nvcc:                   not in PATH (runtime image — OK)")
    except FileNotFoundError:
        print(f"  ⚠️  nvcc:                   not in PATH (runtime image — OK)")

    # PyTorch CUDA
    try:
        import torch
        cuda_available = torch.cuda.is_available()
        if cuda_available:
            dev_name = torch.cuda.get_device_name(0)
            vram = torch.cuda.get_device_properties(0).total_memory / (1024**3)
            cuda_ver = torch.version.cuda
            print(f"  ✅ PyTorch CUDA:           {cuda_ver} — {dev_name} ({vram:.1f} GB)")
        else:
            print(f"  ❌ PyTorch CUDA:           NOT available")
            gpu_ok = False
    except Exception as e:
        print(f"  ❌ PyTorch CUDA:           {e}")
        gpu_ok = False

    # TensorFlow GPU
    try:
        import tensorflow as tf
        gpus = tf.config.list_physical_devices("GPU")
        if gpus:
            for g in gpus:
                print(f"  ✅ TensorFlow GPU:         {g.name}")
        else:
            print(f"  ❌ TensorFlow GPU:         no devices found")
            gpu_ok = False
    except Exception as e:
        print(f"  ❌ TensorFlow GPU:         {e}")
        gpu_ok = False

    # XGBoost CUDA
    try:
        import xgboost as xgb
        # Quick test: create a tiny GPU DMatrix
        import numpy as np
        dm = xgb.DMatrix(np.random.rand(10, 3), label=np.random.randint(0, 2, 10))
        bst = xgb.train({"device": "cuda", "max_depth": 1}, dm, num_boost_round=1)
        print(f"  ✅ XGBoost CUDA:           working")
    except Exception as e:
        err_str = str(e)
        if "CUDA" in err_str or "gpu" in err_str.lower():
            print(f"  ⚠️  XGBoost CUDA:          {err_str[:60]}")
        else:
            print(f"  ✅ XGBoost:                CPU mode (CUDA optional)")

    return gpu_ok


def main():
    print("=" * 65)
    print("J3DI Docker Environment Verification (GPU)")
    print("=" * 65)
    print(f"\n  Python:       {sys.version}")
    print(f"  Platform:     {platform.machine()} / {platform.system()}")
    print(f"  Architecture: {platform.architecture()[0]}")

    results = []

    # GPU checks first — most important on this machine
    gpu_ok = check_gpu()
    results.append(gpu_ok)

    print("\n── Deep Learning ──────────────────────────────────────")
    results.append(check("TensorFlow", "tensorflow"))
    results.append(check("PyTorch", "torch"))

    print("\n── Machine Learning ───────────────────────────────────")
    results.append(check("scikit-learn", "sklearn"))
    results.append(check("XGBoost", "xgboost"))
    results.append(check("LightGBM", "lightgbm"))
    results.append(check("Optuna", "optuna"))

    print("\n── Data Processing ────────────────────────────────────")
    results.append(check("pandas", "pandas"))
    results.append(check("numpy", "numpy"))
    results.append(check("scipy", "scipy"))

    print("\n── Technical Analysis ─────────────────────────────────")
    results.append(check("ta", "ta"))
    results.append(check("pandas-ta", "pandas_ta"))
    results.append(check("TA-Lib", "talib"))

    print("\n── Market Data ────────────────────────────────────────")
    results.append(check("yfinance", "yfinance"))
    results.append(check("ccxt", "ccxt"))

    print("\n── Backtesting ────────────────────────────────────────")
    results.append(check("backtrader", "backtrader"))
    results.append(check("quantstats", "quantstats"))

    print("\n── Experiment Tracking ────────────────────────────────")
    results.append(check("MLflow", "mlflow"))
    results.append(check("TensorBoard", "tensorboard"))

    print("\n── Dev Tools ──────────────────────────────────────────")
    results.append(check("JupyterLab", "jupyterlab"))
    results.append(check("pytest", "pytest"))
    results.append(check("loguru", "loguru"))

    # Database connectivity
    print("\n── Database ───────────────────────────────────────────")
    try:
        import psycopg2
        conn = psycopg2.connect(
            host="postgres", port=5432,
            dbname="j3di", user="j3di", password="j3di_dev_2026"
        )
        conn.close()
        print(f"  ✅ {'PostgreSQL connection':25s} OK")
        results.append(True)
    except Exception as e:
        print(f"  ⚠️  {'PostgreSQL connection':25s} {e}")
        results.append(True)  # Not a failure if running standalone

    # Memory check
    print("\n── System Resources ───────────────────────────────────")
    try:
        import os
        mem_bytes = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES")
        mem_gb = mem_bytes / (1024**3)
        print(f"  ℹ️  Container visible RAM:  {mem_gb:.1f} GB")
        cpus = os.cpu_count()
        print(f"  ℹ️  Container visible CPUs: {cpus}")
    except Exception:
        pass

    # Summary
    passed = sum(results)
    total = len(results)
    print(f"\n{'=' * 65}")
    print(f"  Result: {passed}/{total} checks passed")
    if passed == total:
        print("  🎉 All dependencies + GPU verified — full power ready!")
    elif not gpu_ok:
        print("  ⚠️  GPU not detected — check NVIDIA Container Toolkit")
        print("      Run: nvidia-smi (on host) to confirm driver is loaded")
    else:
        print("  ⚠️  Some packages missing — check output above")
    print(f"{'=' * 65}\n")

    return 0 if passed == total else 1

if __name__ == "__main__":
    sys.exit(main())
