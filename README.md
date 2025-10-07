# Enhanced Dynatrace Extension for Redpanda

**Version 1.0.5 | Production Ready**

A comprehensive Dynatrace Extensions 2.0 integration providing complete observability for Redpanda clusters.

**GitHub Repository:** https://github.com/vuldin/redpanda-dynatrace-extension

---

## Overview

This extension addresses critical gaps in the official Dynatrace Redpanda integration by providing **23 production-grade metrics** across 9 monitoring categories.

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
   # Upload dist/custom:redpanda.enhanced-1.0.5-signed.zip to Dynatrace UI
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
   - Should see: 23 metrics

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

### ❌ Service & Error Metrics (7)
- Schema Registry/REST Proxy errors
- Topic request bytes
- RPC connections
- Consumer group offsets and lag (max/sum)

**Total: 23 metrics** (21 without consumer lag enabled)

---

## Comparison with Official Integration

| Category | Official | Enhanced |
|----------|----------|----------|
| Partition Health | ❌ None | ✅ Complete |
| I/O Performance | ❌ None | ✅ Read/Write Ops |
| Consumer Lag | ⚠️ Partial | ✅ Max + Sum |
| Infrastructure | ⚠️ Basic | ✅ Detailed |
| Service Errors | ⚠️ Partial | ✅ Complete |

**Result:** 91% success rate, 100% of critical metrics

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

### 1.0.5 (Current - October 7, 2025)
- ✅ Fixed uptime metric
- ✅ 23 metrics collected (21 without consumer lag config)
- ✅ 91% success rate, 100% of critical metrics
- ✅ Production ready

### Known Limitations
- Histogram latency metrics not supported (Dynatrace Extensions 2.0 platform limitation)
- Consumer lag metrics require Redpanda configuration: `rpk cluster config set enable_consumer_group_metrics '["group", "partition", "consumer_lag"]'`

---

## Resources

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
