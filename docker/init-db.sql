-- ══════════════════════════════════════════════════════════════════════════════
-- J3DI Trading System — Database Initialization
-- Runs once on first container startup
-- ══════════════════════════════════════════════════════════════════════════════

-- MLflow needs its own database
CREATE DATABASE mlflow OWNER j3di;

-- ── Schemas for trade data ──────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS backtest;
CREATE SCHEMA IF NOT EXISTS journal;

-- ── Backtest Results ────────────────────────────────────────────────────────
CREATE TABLE backtest.runs (
    id              SERIAL PRIMARY KEY,
    run_id          VARCHAR(64) UNIQUE NOT NULL,
    algorithm       VARCHAR(128) NOT NULL,
    symbol          VARCHAR(32) NOT NULL,
    timeframe       VARCHAR(8) NOT NULL,
    start_date      TIMESTAMP NOT NULL,
    end_date        TIMESTAMP NOT NULL,
    config_json     JSONB NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE backtest.trades (
    id              SERIAL PRIMARY KEY,
    run_id          VARCHAR(64) REFERENCES backtest.runs(run_id),
    direction       VARCHAR(5) NOT NULL,           -- LONG / SHORT
    entry_time      TIMESTAMP NOT NULL,
    entry_price     NUMERIC(18,8) NOT NULL,
    exit_time       TIMESTAMP,
    exit_price      NUMERIC(18,8),
    pnl             NUMERIC(18,8),
    pnl_pct         NUMERIC(10,6),
    confidence      NUMERIC(5,4),
    metadata_json   JSONB
);

CREATE TABLE backtest.metrics (
    id              SERIAL PRIMARY KEY,
    run_id          VARCHAR(64) REFERENCES backtest.runs(run_id),
    total_trades    INTEGER,
    win_rate        NUMERIC(6,4),
    sharpe_ratio    NUMERIC(8,4),
    max_drawdown    NUMERIC(8,4),
    total_return    NUMERIC(10,4),
    profit_factor   NUMERIC(8,4),
    metrics_json    JSONB,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ── Trade Journal (for forward testing / paper trading) ─────────────────────
CREATE TABLE journal.trades (
    id              SERIAL PRIMARY KEY,
    environment     VARCHAR(8) DEFAULT 'dev',      -- dev / demo / live
    symbol          VARCHAR(32) NOT NULL,
    direction       VARCHAR(5) NOT NULL,
    entry_time      TIMESTAMP NOT NULL,
    entry_price     NUMERIC(18,8) NOT NULL,
    exit_time       TIMESTAMP,
    exit_price      NUMERIC(18,8),
    stop_loss       NUMERIC(18,8),
    take_profit_1   NUMERIC(18,8),
    take_profit_2   NUMERIC(18,8),
    confluence_score INTEGER,
    ml_confidence   NUMERIC(5,4),
    pnl             NUMERIC(18,8),
    notes           TEXT,
    metadata_json   JSONB,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ── Indexes ─────────────────────────────────────────────────────────────────
CREATE INDEX idx_bt_trades_run    ON backtest.trades(run_id);
CREATE INDEX idx_bt_metrics_run   ON backtest.metrics(run_id);
CREATE INDEX idx_jnl_symbol_time  ON journal.trades(symbol, entry_time);
