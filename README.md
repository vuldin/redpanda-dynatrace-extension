# Enhanced Dynatrace Extension for Redpanda

**Version 1.0.11 | Production Ready**

A comprehensive Dynatrace Extensions 2.0 integration providing complete observability for Redpanda clusters.

**GitHub Repository:** https://github.com/vuldin/redpanda-dynatrace-extension

---

## Overview

This extension provides **40 production-grade metrics** with **100% feature parity** to the official Dynatrace Redpanda integration (29 metrics), plus 2 additional unique critical metrics. This makes the enhanced extension a **complete superset** of the official implementation with **zero metric limitations**.

### What's Included

✅ **Critical Production Metrics:**
- Under-replicated replicas (data loss risk)
- Unavailable partitions (service outage)
- Disk space alerts
- Leadership changes (cluster instability)
- RPC timeouts (network issues)

✅ **Infrastructure Metrics:**
- CPU, memory, disk monitoring
- Uptime tracking

✅ **Performance Metrics:**
- I/O operations (read/write)
- Producer/consumer throughput
- Consumer group lag tracking
- **Request latency histograms with percentiles (p50, p75, p90, p95, p99)**

✅ **Service Monitoring:**
- Schema Registry errors
- REST Proxy errors
- Topic-level metrics

---

## Quick Deploy (30 Minutes)

### Prerequisites
- Dynatrace 1.310+ with ActiveGate
- Redpanda cluster with Prometheus metrics on port 9644
- `dt-cli` installed: `pipx install dt-cli`

### Steps

1. **Clone Repository**
   ```bash
   git clone https://github.com/vuldin/redpanda-dynatrace-extension.git
   cd redpanda-dynatrace-extension
   ```

2. **Generate Certificates**
   ```bash
   ./scripts/setup-certificates-dtcli.sh
   ```

3. **Upload CA to Dynatrace**
   - Settings → Credential Vault → Add Certificate
   - Upload: `extension/certs/ca.pem`

4. **Copy CA to ActiveGate** (if not Docker)
   ```bash
   sudo cp extension/certs/ca.pem /var/lib/dynatrace/remotepluginmodule/agent/conf/certificates/
   sudo systemctl restart dynatracegateway
   ```

5. **Build & Upload Extension**
   ```bash
   ./scripts/build-and-sign-dtcli.sh
   # Upload dist/custom:redpanda.enhanced-1.0.11-signed.zip to Dynatrace UI
   ```

6. **Configure Monitoring**
   - Extensions → custom:redpanda.enhanced → Add monitoring configuration
   - Endpoint: `http://REDPANDA_HOST:9644/public_metrics`

7. **Enable Consumer Lag** (Recommended)
   ```bash
   rpk cluster config set enable_consumer_group_metrics '["group", "partition", "consumer_lag"]'
   ```

8. **Verify** (wait 2-3 minutes)
   - Metrics → Search: `redpanda`
   - Should see: 40 metrics

---

## Project Structure

```
.
├── extension/
│   ├── extension.yaml          # Main extension definition (edit to add metrics)
│   └── certs/                  # Generated certificates (git ignored)
├── scripts/
│   ├── setup-certificates-dtcli.sh  # Generate CA and developer certificates
│   └── build-and-sign-dtcli.sh      # Build and sign extension (auto-versions)
├── dist/                       # Build output (generated)
├── CLAUDE.md                   # Developer guide for this codebase
└── README.md                   # This file
```

---

## Metrics Catalog

### 🔴 Critical (5)
- `redpanda.kafka.under_replicated_replicas` - Data loss risk (alert when > 0)
- `redpanda.cluster.unavailable_partitions` - Service outage (alert when > 0)
- `redpanda.storage.disk.free_space_alert` - Disk full (alert when == 1)
- `redpanda.raft.leadership.changes` - Cluster instability
- `redpanda.node.status.rpcs_timed_out` - Network issues

### 🖥️ Infrastructure (7)
- CPU busy time, uptime
- Memory (available, free, allocated)
- Disk (free, total space)

### 💾 I/O & Performance (4)
- Read/write operations per second
- Producer/consumer throughput

### ⚡ Latency Metrics (9)
- Kafka request latency histogram (sum, count, buckets with percentiles)
- RPC request latency histogram (sum, count, buckets with percentiles)
- REST Proxy request latency histogram (sum, count, buckets with percentiles)
- **Query p50/p75/p90/p95/p99 percentiles in Data Explorer**

### 🌐 Cluster Topology (4)
- Broker count
- Partition count
- Topic count
- Replica configuration per topic

### 👥 Consumer Group Metadata (5)
- Committed offsets
- Consumer lag (max/sum)
- Consumer count per group
- Topic count per group

### 📊 Partition Tracking (1)
- Max offset (high watermark) per partition

### ℹ️ Application Info (1)
- Build version and revision

### ❌ Service & Error Metrics (2)
- Schema Registry/REST Proxy errors

### 🔌 RPC Connections (1)
- Active RPC connections

### 📨 Topic Metrics (1)
- Topic request bytes

**Total: 40 metrics** (all official metrics + 2 unique + 9 latency histogram-derived metrics)

---

## Comparison with Official Integration

| Category | Official (29 metrics) | Enhanced (40 metrics) |
|----------|----------|----------|
| Partition Health | ⚠️ Partial | ✅ Complete |
| I/O Performance | ✅ Complete | ✅ Complete |
| Consumer Lag | ✅ Complete | ✅ Complete |
| Infrastructure | ⚠️ Basic | ✅ Detailed |
| Service Errors | ⚠️ Partial | ✅ Complete |
| Cluster Topology | ✅ Complete | ✅ Complete |
| Latency Metrics | ✅ Histograms | ✅ **Complete Parity with Percentiles** |

**Result:** Enhanced is a **complete superset** of the official extension with:
- ✅ All 29 official metrics (100% coverage)
- ✅ 2 additional unique critical metrics (disk alert, RPC timeouts)
- ✅ All 3 latency histograms (Kafka, RPC, REST Proxy) with p50/p75/p90/p95/p99 percentile support
- ✅ **Zero metric limitations**

---

## Updating to New Version

1. Delete old version in Custom Extensions Creator (Three-dot menu → Delete)
2. Update version in `extension/extension.yaml`
3. Build and upload: `./scripts/build-and-sign-dtcli.sh`
4. Upload new signed ZIP via Custom Extensions Creator → Import
5. Monitoring configuration auto-updates (no reconfiguration needed)

---

## Troubleshooting

### No Metrics Appearing?

```bash
# Check connectivity
curl http://REDPANDA_HOST:9644/public_metrics

# Verify endpoint in Dynatrace (must be /public_metrics, not /metrics)

# Check ActiveGate logs
sudo tail -100 /var/lib/dynatrace/remotepluginmodule/log/remotepluginmodule.log
```

### Certificate Errors?

```bash
# Re-copy CA to ActiveGate
sudo cp extension/certs/ca.pem /var/lib/dynatrace/remotepluginmodule/agent/conf/certificates/
sudo systemctl restart dynatracegateway
```

---

## Querying Latency Percentiles

The extension collects histogram bucket metrics that enable percentile calculations (p50, p75, p90, p95, p99).

### Data Explorer Queries

**Kafka Request Latency (p95):**
```
redpanda.kafka.request.latency.seconds_bucket.count:splitBy(redpanda_request):percentile(95.0)
```

**Kafka Request Latency (p99):**
```
redpanda.kafka.request.latency.seconds_bucket.count:splitBy(redpanda_request):percentile(99.0)
```

**RPC Latency (p95):**
```
redpanda.rpc.request.latency.seconds_bucket.count:splitBy(redpanda_server):percentile(95.0)
```

**REST Proxy Latency (p99):**
```
redpanda.rest_proxy.request.latency.seconds_bucket.count:percentile(99.0)
```

**Multiple Percentiles:**
- Use Data Explorer dropdown to select: Percentile 10th, 75th, 90th
- For p95 and p99, use the query syntax above in Advanced mode

---

## Critical Alerts to Configure

```dql
// P1: Data Loss Risk
timeseries sum(redpanda.kafka.under_replicated_replicas) > 0

// P1: Service Outage
timeseries sum(redpanda.cluster.unavailable_partitions) > 0

// P1: Disk Full
timeseries max(redpanda.storage.disk.free_space_alert) == 1

// P2: Cluster Instability
timeseries rate(redpanda.raft.leadership.changes.count) > 10/min

// P2: Network Issues
timeseries rate(redpanda.node.status.rpcs_timed_out.count) > 5/min
```

---

## Version History

### 1.0.11 (Current - October 7, 2025)
- ✅ **COMPLETE PARITY ACHIEVED** - Added REST Proxy request latency histogram
- ✅ All 3 latency histograms with percentiles (Kafka, RPC, REST Proxy)
- ✅ **40 metrics total** (all 29 official + 2 unique + 9 latency histogram-derived metrics)
- ✅ **100% feature parity** - Complete superset with zero metric limitations

### 1.0.10 (October 7, 2025)
- ✅ **LATENCY HISTOGRAMS FIXED** - Added `le` dimension for histogram buckets
- ✅ Kafka request latency with percentiles (p50, p75, p90, p95, p99)
- ✅ RPC request latency with percentiles (p50, p75, p90, p95, p99)
- ✅ **37 metrics total** (all official + 2 unique + 6 latency histogram-derived metrics)
- ⚠️ Missing REST Proxy latency (fixed in v1.0.11)

### 1.0.9 (October 7, 2025)
- ✅ Changed latency metrics to `type: histogram`
- ⚠️ Partial success - metrics appeared but percentiles didn't work (missing `le` dimension)

### 1.0.8 (October 7, 2025)
- ✅ Added cluster topology metrics (brokers, partitions, topics, replicas)
- ✅ Added consumer group metadata (consumer count, topic count per group)
- ✅ Added partition max offset tracking
- ✅ Added application build information
- ✅ **31 metrics total** (29 from official + 2 unique)

### 1.0.5 (October 7, 2025)
- ✅ Fixed uptime metric
- ✅ 23 metrics collected
- ✅ 91% success rate, 100% of critical metrics

### Known Limitations
- Consumer lag metrics require Redpanda configuration: `rpk cluster config set enable_consumer_group_metrics '["group", "partition", "consumer_lag"]'`

---

## Migrating from Official Extension

Already using the official Dynatrace Redpanda extension? The enhanced extension is a **complete superset** with zero limitations.

**See the [Migration Guide](MIGRATION-GUIDE.md)** for:
- Step-by-step migration instructions
- What you'll gain (latency histograms, unique metrics)
- Zero downtime migration process
- Rollback procedures

**Key benefit**: All your existing dashboards and alerts will work without changes.

---

## Resources

- **Migration Guide**: [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)
- **Gap Analysis**: [GAP-ANALYSIS.md](GAP-ANALYSIS.md)
- **User Guide**: [REDPANDA-USER-GUIDE.md](REDPANDA-USER-GUIDE.md)
- **Dynatrace Extensions 2.0 Docs**: https://docs.dynatrace.com/docs/extend-dynatrace/extensions20
- **Redpanda Monitoring Docs**: https://docs.redpanda.com/current/manage/monitoring/
- **dt-cli Installation**: `pipx install dt-cli`

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section above
2. Review deployment steps in [Quick Deploy](#quick-deploy-30-minutes)
3. Check Dynatrace and ActiveGate logs for errors
4. Open an issue on [GitHub](https://github.com/vuldin/redpanda-dynatrace-extension/issues)

---

**Built for production Redpanda monitoring**
