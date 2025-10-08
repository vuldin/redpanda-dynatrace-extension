# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**GitHub Repository:** https://github.com/vuldin/redpanda-dynatrace-extension

---

## Project Overview

This repository contains a **production-ready Dynatrace Extensions 2.0 integration** for comprehensive Redpanda monitoring with custom topology support.

**Current Version**: 1.0.13 (October 7, 2025)
**Status**: Production Ready - 100% Feature Parity + Partial Topology
**Metrics**: 40 collected (all official extension metrics + 2 unique + 9 latency histogram-derived metrics)
**Success Rate**: 100% (40/40 metrics - zero limitations)
**Topology**: Cluster and topic entities working (namespace/partition entities limited)

**Key Context**: This custom extension is now a **complete superset** of the official Dynatrace Redpanda extension with **zero limitations**. It includes all 29 official metrics plus 2 additional unique critical metrics (disk alert, RPC timeouts) plus all 3 latency histograms (Kafka, RPC, REST Proxy) with full percentile support (p50, p75, p90, p95, p99). Version 1.0.13 adds custom topology support with cluster and topic entities visible in Smartscape.

---

## Quick Reference

### Build and Deploy
```bash
# Generate certificates (one-time setup)
./scripts/setup-certificates-dtcli.sh

# Build and sign extension (auto-versions from extension.yaml)
./scripts/build-and-sign-dtcli.sh
# Output: dist/custom:redpanda.enhanced-1.0.5-signed.zip

# Upload via Dynatrace UI (Custom Extensions Creator → Import)
```

### Key Files
- `extension/extension.yaml` - Extension definition (edit to add/modify metrics)
- `scripts/setup-certificates-dtcli.sh` - Generate CA and developer certificates
- `scripts/build-and-sign-dtcli.sh` - Build and sign (auto-versions output)
- `QUICK-DEPLOY-REFERENCE.md` - One-page deployment guide
- `REDPANDA-USER-GUIDE.md` - Comprehensive user documentation
- `SUMMARY.md` - Technical summary and gap analysis

---

## Architecture

### Extension Structure

**`extension/extension.yaml`** - Main extension definition (462 lines)
- 9 metric groups organized by category
- Uses Prometheus data source to scrape Redpanda's `/public_metrics` endpoint (port 9644)
- Maps Prometheus metrics to Dynatrace metric keys with dimensions
- Structure: `prometheus:` section → groups → subgroups → metrics
- Global `metrics:` section defines metadata for all metrics

**Key Pattern:**
```yaml
prometheus:
  - group: partition_health
    interval:
      minutes: 1
    dimensions:
      - key: redpanda_cluster
        value: label:redpanda_cluster  # Extract from Prometheus label
    metrics:
      - key: redpanda.kafka.under_replicated_replicas      # Dynatrace key
        value: metric:redpanda_kafka_under_replicated_replicas  # Prometheus metric
        type: gauge  # or count

metrics:  # Global metadata section
  - key: redpanda.kafka.under_replicated_replicas
    metadata:
      displayName: Under-Replicated Replicas
      description: Partitions not fully replicated - DATA LOSS RISK
      unit: Count
      metricProperties:
        minValue: 0
        rootCauseRelevant: true
        impactRelevant: true
        valueType: unknown
```

### Metric Categories

1. **Latency** (3 histograms → 9 metrics in Dynatrace UI) - ✅ **FULLY SUPPORTED**
   - `redpanda.kafka.request.latency.seconds` (histogram)
   - `redpanda.rpc.request.latency.seconds` (histogram)
   - `redpanda.rest_proxy.request.latency.seconds` (histogram)
   - Each histogram produces: `_bucket`, `_count`, `_sum` metrics in Dynatrace
   - Supports percentile queries: p50, p75, p90, p95, p99

2. **I/O Performance** (2 metrics)
   - `redpanda.io.queue.read.ops.total`
   - `redpanda.io.queue.write.ops.total`

3. **Partition Health** (4 metrics) - **CRITICAL**
   - `redpanda.kafka.under_replicated_replicas` (alert when > 0)
   - `redpanda.cluster.unavailable_partitions` (alert when > 0)
   - `redpanda.raft.leadership.changes`
   - `redpanda.node.status.rpcs_timed_out`

4. **Throughput** (2 metrics)
   - `redpanda.rpc.received.bytes` (producer)
   - `redpanda.rpc.sent.bytes` (consumer)

5. **Infrastructure** (7 metrics)
   - CPU: `redpanda.cpu.busy.seconds.total`
   - Uptime: `redpanda.uptime.seconds.total`
   - Memory: available, free, allocated
   - Disk: free, total, free_space_alert

6. **Service Errors** (2 metrics)
   - `redpanda.schema_registry.request.errors.total`
   - `redpanda.rest_proxy.request.errors.total`

7. **Consumer Groups** (5 metrics)
   - `redpanda.kafka.consumer_group.committed_offset`
   - `redpanda.kafka.consumer_group.lag.max`
   - `redpanda.kafka.consumer_group.lag.sum`
   - `redpanda.kafka.consumer_group.consumers` (NEW in v1.0.8)
   - `redpanda.kafka.consumer_group.topics` (NEW in v1.0.8)
   - **Note**: Lag metrics require Redpanda config: `rpk cluster config set enable_consumer_group_metrics '["group", "partition", "consumer_lag"]'`

8. **Cluster Topology** (4 metrics) - NEW in v1.0.8
   - `redpanda.cluster.brokers` - Number of brokers in cluster
   - `redpanda.cluster.partitions` - Total partition count
   - `redpanda.cluster.topics` - Total topic count
   - `redpanda.kafka.replicas` - Replica configuration per topic

9. **Partition Tracking** (1 metric) - NEW in v1.0.8
   - `redpanda.kafka.max_offset` - Max offset (high watermark) per partition

10. **Application Info** (1 metric) - NEW in v1.0.8
    - `redpanda.application.build` - Build version and revision

11. **Topics/Partitions** (1 metric)
    - `redpanda.kafka.request.bytes.total`

12. **RPC Connections** (1 metric)
    - `redpanda.rpc.active_connections`

---

## Topology Configuration

**Version 1.0.13** adds custom topology support creating entities in Dynatrace Smartscape.

### Entity Types Defined

Four entity types are defined in the `topology:` section of extension.yaml (lines 6-99):

1. **redpanda:cluster** - Cluster-level entities
2. **redpanda:namespace** - Namespace entities
3. **redpanda:topic** - Topic entities
4. **redpanda:partition** - Partition entities

### Entity Relationships

Three CHILD_OF relationships create hierarchy:
- Namespace → Cluster
- Topic → Namespace
- Partition → Topic

### Working vs Not Working

**✅ Working (entities created):**
- **Cluster entities** - Created from `redpanda.cluster.brokers` metric which has `redpanda_cluster: const:your-redpanda-cluster` dimension
- **Topic entities** - Created from `redpanda.kafka.replicas` metric which has `redpanda_cluster` dimension

**❌ Not Working (entities defined but not instantiated):**
- **Namespace entities** - Cannot get `redpanda_cluster` dimension on namespace-only metrics
- **Partition entities** - Cannot get `redpanda_cluster` dimension on partition-level metrics like `under_replicated_replicas`

### Root Cause: Const Dimension Limitation

After extensive testing (v1.0.14 through v1.0.22), we discovered a Dynatrace Extensions 2.0 limitation:

**The `const:` dimension approach doesn't consistently apply to all metrics**, even when:
- Metrics are in the same group with identical dimension configuration
- Metrics are in subgroups inheriting parent dimensions
- Dimensions are explicitly defined at every level

**Example:** In the same `topics_partitions` group:
- `kafka.replicas` ✅ Gets `redpanda_cluster` dimension
- `kafka.under_replicated_replicas` ❌ Does NOT get `redpanda_cluster` dimension

This appears to be non-deterministic behavior in how Dynatrace processes const dimensions for Prometheus-based extensions.

### Entity ID Patterns

**Cluster:**
```
redpanda_cluster_{redpanda_cluster}
```

**Topic:**
```
redpanda_topic_{redpanda_cluster}_{redpanda_namespace}_{redpanda_topic}
```

### Viewing Entities

```dql
# List all cluster entities
fetch dt.entity.redpanda:cluster

# List all topic entities
fetch dt.entity.redpanda:topic
```

Or navigate to: **Observe and explore → Entities** → Filter by `redpanda:cluster` or `redpanda:topic`

### Cluster Name Configuration

The cluster name is defined as a static constant in extension.yaml (line 106, 143, etc.):
```yaml
- key: redpanda_cluster
  value: const:your-redpanda-cluster
```

To change the cluster name, update all instances of `const:your-redpanda-cluster` to `const:your-actual-cluster-name` before building.

---

## Development Workflow

### Adding New Metrics

1. **Verify metric exists in Redpanda:**
   ```bash
   curl http://redpanda-host:9644/public_metrics | grep "metric_name"
   ```

2. **Add to appropriate group in `extension.yaml`:**
   ```yaml
   prometheus:
     - group: partition_health  # Choose appropriate group
       metrics:
         - key: redpanda.new.metric.name
           value: metric:redpanda_new_metric_name
           type: gauge  # or count
   ```

3. **Add metadata in global `metrics:` section:**
   ```yaml
   metrics:
     - key: redpanda.new.metric.name
       metadata:
         displayName: Human Readable Name
         description: Detailed description
         unit: Count  # or Second, Byte
         metricProperties:
           minValue: 0
           rootCauseRelevant: true  # Useful for troubleshooting
           impactRelevant: true     # Affects user experience
           valueType: unknown
   ```

4. **Update version in `extension.yaml`:**
   ```yaml
   version: 1.0.6  # Increment from 1.0.5
   ```

5. **Build and test:**
   ```bash
   ./scripts/build-and-sign-dtcli.sh
   # Output: dist/custom:redpanda.enhanced-1.0.6-signed.zip
   ```

### Updating Existing Metrics

**Example: Fixing metric name**

In `extension.yaml`, update both the `prometheus:` section and `metrics:` section:
```yaml
prometheus:
  - group: infrastructure
    metrics:
      - key: redpanda.uptime.seconds.total
        value: metric:redpanda_application_uptime_seconds_total  # Fixed name
        type: gauge  # Fixed type

metrics:
  - key: redpanda.uptime.seconds.total
    metadata:
      displayName: Uptime
      description: Total broker uptime
      # ... rest of metadata
```

### Deploying New Version

1. **Delete old version** in Dynatrace Custom Extensions Creator
2. **Update version** in `extension.yaml`
3. **Build and sign**: `./scripts/build-and-sign-dtcli.sh`
4. **Upload** via Dynatrace UI
5. **Monitoring configuration auto-updates** - no reconfiguration needed

---

## Critical Concepts

### Dynatrace Extensions 2.0

**Metric Types:**
- `gauge` - Point-in-time value (memory, lag, active connections)
- `count` - Cumulative counter, Dynatrace calculates rate (bytes, operations)
- Histogram `_sum`/`_count` - **NOT SUPPORTED** in Extensions 2.0 Prometheus data source

**Dimension Sources:**
- `label:prometheus_label` - Extract from Prometheus metric label
- `const:static_value` - Static value for all metrics

**Extension Naming:**
- Namespace: `custom:` (required for custom extensions)
- Name: `redpanda.enhanced`
- Full name: `custom:redpanda.enhanced`

### Certificate Chain (Required for Signing)

Dynatrace requires proper PKI chain:
1. **CA Certificate** (`ca.pem`) - Generated with `dt ext genca`
2. **Developer Certificate** (`dev.pem`) - Generated from CA with `dt ext generate-developer-pem`
3. **Upload CA to Dynatrace** - Settings → Credential Vault → Add Certificate
4. **Copy CA to ActiveGate** - `/var/lib/dynatrace/remotepluginmodule/agent/conf/certificates/ca.pem`
5. **Sign extension with developer cert** - Done by `build-and-sign-dtcli.sh`

**Location**: `extension/certs/` (git ignored)

### Redpanda Metrics Endpoint

**Correct endpoint**: `http://redpanda-host:9644/public_metrics`
**NOT**: `http://redpanda-host:9644/metrics` (this is a different endpoint)

**Consumer Lag Requirement:**
```bash
# Required to expose consumer_group_lag_max and consumer_group_lag_sum
rpk cluster config set enable_consumer_group_metrics '["group", "partition", "consumer_lag"]'
```

### dt-cli Installation

**Correct method:**
```bash
pipx install dt-cli
```

**Command name**: `dt` (NOT `dt-cli`)

**Available commands:**
- `dt ext genca` - Generate CA certificate
- `dt ext generate-developer-pem` - Generate developer certificate from CA
- `dt ext assemble` - Build extension ZIP
- `dt ext sign` - Sign extension with developer certificate

---

## Build Scripts

### `scripts/setup-certificates-dtcli.sh`

**Purpose**: Generate CA and developer certificates (one-time setup)

**Usage:**
```bash
./scripts/setup-certificates-dtcli.sh
```

**Output:**
- `extension/certs/ca.pem` - CA certificate (upload to Dynatrace)
- `extension/certs/ca.key` - CA private key (keep secure)
- `extension/certs/dev.pem` - Developer certificate (for signing)

**Key features:**
- Checks if CA already exists
- Prompts before overwriting existing CA
- Automatically generates developer cert from CA

### `scripts/build-and-sign-dtcli.sh`

**Purpose**: Build and sign extension with auto-versioning

**Usage:**
```bash
./scripts/build-and-sign-dtcli.sh
```

**Process:**
1. Extracts version from `extension.yaml`
2. Cleans up old build artifacts
3. Builds extension: `dt ext assemble --src extension --output extension.zip`
4. Signs extension: `dt ext sign --src extension.zip --key dev.pem --output bundle.zip`
5. Moves to `dist/custom:redpanda.enhanced-{VERSION}-signed.zip`

**Key features:**
- Auto-versions output filename from `extension.yaml`
- No manual version updates needed
- Validates certificate exists before signing

---

## Deployment Methods

### Production Deployment (Documented in User Guides)

**Method**: Dynatrace Custom Extensions Creator (Web UI)

**Steps:**
1. Generate certificates: `./scripts/setup-certificates-dtcli.sh`
2. Upload CA to Dynatrace Credential Vault
3. Copy CA to ActiveGate host (if not Docker)
4. Build and sign: `./scripts/build-and-sign-dtcli.sh`
5. Upload signed ZIP via Custom Extensions Creator → Import
6. Configure monitoring (endpoint, cluster name)

**Advantages:**
- No API token needed
- Visual interface
- Easy troubleshooting

### Alternative Methods (Not Documented)

- Direct API upload (requires API token with `extensions:write` scope)
- dt-cli upload (requires `.dtcli` config file)

---

## Known Issues and Limitations

### 1. ✅ Histogram Latency Metrics - RESOLVED in v1.0.10-11

**Previous Issue**: Histogram `_sum` and `_count` metrics didn't appear in Dynatrace

**Solution**: Use `type: histogram` and add `le` dimension for bucket collection

**Result**: Full histogram support with percentile calculations (p50, p75, p90, p95, p99)

**Metrics added:**
- v1.0.10: Kafka request latency, RPC request latency
- v1.0.11: REST Proxy request latency (complete parity with official extension)

**Query syntax:**
```
redpanda.kafka.request.latency.seconds_bucket.count:splitBy(redpanda_request):percentile(95.0)
redpanda.rpc.request.latency.seconds_bucket.count:splitBy(redpanda_server):percentile(99.0)
redpanda.rest_proxy.request.latency.seconds_bucket.count:percentile(99.0)
```

**Status**: ✅ **FIXED** - All 3 latency histograms now working

### 2. Consumer Lag Metrics Require Configuration

**Issue**: `consumer_group_lag_max` and `consumer_group_lag_sum` don't appear by default

**Cause**: Redpanda doesn't expose lag metrics without explicit configuration

**Fix**:
```bash
rpk cluster config set enable_consumer_group_metrics '["group", "partition", "consumer_lag"]'
```

**Status**: Documented in all user guides as optional step

### 3. Service Error Metrics May Not Appear

**Issue**: Schema Registry and REST Proxy error metrics may be zero or missing

**Cause**: These metrics only appear if Schema Registry or REST Proxy are enabled and have traffic

**Status**: Expected behavior, not a bug

---

## Testing and Verification

### Pre-deployment Checks

```bash
# 1. Check Redpanda endpoint is accessible
curl http://redpanda-host:9644/public_metrics | head

# 2. Verify specific metrics exist
curl http://redpanda-host:9644/public_metrics | grep -E "(under_replicated|unavailable_partitions|disk_free_space_alert)"

# 3. Check consumer lag metrics (if enabled)
curl http://redpanda-host:9644/public_metrics | grep "consumer_group_lag"
```

### Post-deployment Verification

**In Dynatrace UI:**
1. **Metrics** → Search: `redpanda`
2. **Expected**: 40 metrics (38 without consumer lag)
3. **Extension Status**: Extensions → custom:redpanda.enhanced → Should show "OK"

**Data Explorer Query:**
```
redpanda.kafka.under_replicated_replicas:splitBy(redpanda_cluster):avg()
```

**ActiveGate Logs:**
```bash
sudo tail -100 /var/lib/dynatrace/remotepluginmodule/log/remotepluginmodule.log | grep redpanda
```

---

## Common Issues

### Extension Upload Failed

**Error**: "extension.zip ZIP entry not found"
**Cause**: Wrong ZIP structure
**Fix**: Use `build-and-sign-dtcli.sh` (creates nested ZIP structure)

### Certificate Validation Failed

**Error**: "Extension signature is not valid"
**Cause**: CA not uploaded to Dynatrace or not copied to ActiveGate
**Fix**:
1. Upload `ca.pem` to Dynatrace Credential Vault
2. Copy to ActiveGate: `sudo cp extension/certs/ca.pem /var/lib/dynatrace/remotepluginmodule/agent/conf/certificates/`
3. Restart: `sudo systemctl restart dynatracegateway`

### No Metrics Appearing

**Error**: Metrics list is empty in Dynatrace
**Diagnosis**:
```bash
curl http://redpanda-host:9644/public_metrics
```

**Common causes:**
1. **Wrong endpoint**: Must be `/public_metrics` not `/metrics`
2. **Network issue**: ActiveGate can't reach Redpanda on port 9644
3. **Docker networking**: Use container IP (e.g., `172.18.0.2`) not `localhost`

### Schema Validation Errors

**Error**: "does not match the regex pattern" or "is not defined in the schema"
**Cause**: Invalid YAML structure
**Rules**:
- No `featureSet: default` (rejected by regex)
- No inline metadata in `prometheus:` section
- All metrics must have entry in global `metrics:` section

---

## Version History

### 1.0.13 (Current - October 7, 2025)
- ✅ **CUSTOM TOPOLOGY SUPPORT** - Cluster and topic entities in Smartscape
- ✅ Entity-based health tracking and problem correlation
- ✅ Visual topology navigation for clusters and topics
- ✅ Entity selector query support
- ⚠️ Namespace/partition entities defined but not instantiated (Dynatrace const dimension limitation discovered after testing v1.0.14-1.0.22)
- ✅ All 40 metrics continue working with 100% feature parity
- 📝 Documented topology limitation with root cause analysis

### 1.0.11 (October 7, 2025)
- ✅ **COMPLETE PARITY ACHIEVED** - Added REST Proxy request latency histogram
- ✅ REST Proxy request latency with full percentile support (p50, p75, p90, p95, p99)
- ✅ **40 metrics total** (all 29 official + 2 unique + 9 latency histogram-derived metrics)
- ✅ **100% feature parity** - Complete superset with zero metric limitations
- ✅ **100% success rate** (40/40 metrics working)
- ✅ All 3 latency histograms from official extension now included

### 1.0.10 (October 7, 2025)
- ✅ **LATENCY HISTOGRAMS FIXED** - Added `le` dimension for histogram bucket collection
- ✅ Kafka request latency with full percentile support (p50, p75, p90, p95, p99)
- ✅ RPC request latency with full percentile support (p50, p75, p90, p95, p99)
- ✅ **37 metrics total** (all official + 2 unique + 6 latency histogram-derived metrics)
- ⚠️ Missing REST Proxy latency (fixed in v1.0.11)

### 1.0.9 (October 7, 2025)
- ✅ Changed latency metrics to `type: histogram`
- ⚠️ Partial success - metrics appeared (35 total) but percentiles didn't work (missing `le` dimension)

### 1.0.8 (October 7, 2025)
- **Feature parity achieved** - All non-latency official extension metrics included
- Added cluster topology metrics (brokers, partitions, topics, replicas)
- Added consumer group metadata (consumer count, topic count per group)
- Added partition max offset tracking
- Added application build information
- **31 metrics total** (29 from official + 2 unique)
- **True superset** (except latency metrics)

### 1.0.5 (October 7, 2025)
- Fixed uptime metric name: `redpanda_uptime_seconds_total` → `redpanda_application_uptime_seconds_total`
- Changed uptime metric type: `count` → `gauge`
- Updated all documentation with consumer lag configuration
- 23 metrics collected (21 without consumer lag)
- 91% success rate, 100% of critical metrics

### 1.0.4 (October 7, 2025)
- Attempted histogram fix with type: gauge (failed)
- Build script auto-versioning added

### 1.0.3 (October 7, 2025)
- Attempted histogram fix (failed)

### 1.0.2 (October 7, 2025)
- Attempted histogram metrics with type: count (failed)

### 1.0.1 (October 6, 2025)
- Fixed schema validation errors
- Removed `featureSet: default` and inline metadata
- 19 metrics working

### 1.0.0 (October 5, 2025)
- Initial release with 30+ metric definitions
- Certificate setup and build automation

---

## Documentation Structure

### User-Facing Documentation

1. **README.md**
   - Project overview with quick start
   - Current status and capabilities
   - Links to detailed guides
   - Target: First-time visitors

2. **REDPANDA-USER-GUIDE.md**
   - Comprehensive deployment guide
   - Detailed troubleshooting
   - Configuration and updates
   - Target: Users managing the extension

3. **GAP-ANALYSIS.md**
   - Feature comparison with official extension
   - Complete metrics catalog
   - Migration recommendations
   - Target: Technical decision-makers

4. **MIGRATION-GUIDE.md**
   - Step-by-step migration from official extension
   - What you gain/lose
   - Rollback procedures
   - Target: Users migrating from official extension

5. **TOPOLOGY-DRAFT.md**
   - Topology implementation details
   - Working vs. limited entity types
   - Root cause analysis of limitations
   - Target: Developers understanding topology

### Developer Documentation

6. **CLAUDE.md** (this file)
   - Development guide
   - Architecture and patterns
   - Target: Contributors and AI assistants

---

## Important Rules

### YAML Structure

1. **Metric keys must be unique** across entire extension
2. **Prometheus metric names** use underscore: `redpanda_kafka_request_latency_seconds`
3. **Dynatrace metric keys** use dots: `redpanda.kafka.request.latency.seconds`
4. **All metrics** in `prometheus:` section must have entry in `metrics:` section
5. **No `featureSet: default`** - explicitly rejected by schema validation
6. **No inline metadata** in `prometheus:` section - use global `metrics:` section

### Version Management

1. **Always increment version** in `extension.yaml` for any changes
2. **Build script auto-versions** output filename - no manual updates needed
3. **Delete old version** in Dynatrace before uploading new version
4. **Monitoring configurations auto-update** - no reconfiguration needed

### Certificate Management

1. **CA certificate** must be uploaded to Dynatrace Credential Vault
2. **CA certificate** must be copied to ActiveGate host
3. **Developer certificate** generated from CA, not self-signed
4. **Certificates are git ignored** - stored in `extension/certs/`

---

## Critical Metrics for Production

Configure these alerts after deployment:

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

## Resources

- **Dynatrace Extensions 2.0 Docs**: https://docs.dynatrace.com/docs/extend-dynatrace/extensions20
- **Redpanda Monitoring Docs**: https://docs.redpanda.com/current/manage/monitoring/
- **dt-cli Installation**: `pipx install dt-cli`

---

## Contributing

When making changes:
1. Modify `extension/extension.yaml`
2. Update version number
3. Run `./scripts/build-and-sign-dtcli.sh`
4. Test in non-production environment
5. Update user documentation if needed
6. Update this file (CLAUDE.md) if architecture changes
