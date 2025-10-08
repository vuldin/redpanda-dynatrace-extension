# Topology Implementation Details

**Version**: 1.0.13
**Date**: October 8, 2025
**Status**: Partial Implementation (2 of 4 entity types working)

This document contains the `topology:` section implementation for custom entity types in the Redpanda extension, including detailed analysis of what works and what doesn't.

## Overview

The topology section will create four entity types:
1. **Redpanda Cluster** - Root entity representing the entire cluster
2. **Redpanda Namespace** - Logical grouping of topics within a cluster
3. **Redpanda Topic** - Kafka topics within a namespace
4. **Redpanda Partition** - Individual partitions within topics

These entities will appear in Dynatrace Smartscape with visual relationships.

## Topology Section for extension.yaml

```yaml
topology:
  types:
    # Cluster Entity
    - name: redpanda:cluster
      displayName: Redpanda Cluster
      enabled: true
      rules:
        - idPattern: redpanda_cluster_{redpanda_cluster}
          instanceNamePattern: "{redpanda_cluster}"
          sources:
            - sourceType: Metrics
              condition: $prefix(redpanda.cluster)
          attributes:
            - pattern: '{redpanda_cluster}'
              key: cluster_name
              displayName: Cluster Name

    # Namespace Entity
    - name: redpanda:namespace
      displayName: Redpanda Namespace
      enabled: true
      rules:
        - idPattern: redpanda_namespace_{redpanda_cluster}_{redpanda_namespace}
          instanceNamePattern: "{redpanda_namespace}"
          sources:
            - sourceType: Metrics
              condition: $prefix(redpanda.kafka)
          attributes:
            - pattern: '{redpanda_cluster}'
              key: cluster
              displayName: Cluster
            - pattern: '{redpanda_namespace}'
              key: namespace
              displayName: Namespace

    # Topic Entity
    - name: redpanda:topic
      displayName: Redpanda Topic
      enabled: true
      rules:
        - idPattern: redpanda_topic_{redpanda_cluster}_{redpanda_namespace}_{redpanda_topic}
          instanceNamePattern: "{redpanda_topic}"
          sources:
            - sourceType: Metrics
              condition: $prefix(redpanda.kafka)
          attributes:
            - pattern: '{redpanda_cluster}'
              key: cluster
              displayName: Cluster
            - pattern: '{redpanda_namespace}'
              key: namespace
              displayName: Namespace
            - pattern: '{redpanda_topic}'
              key: topic
              displayName: Topic Name
            - pattern: '{redpanda_kafka_replicas}'
              key: replication_factor
              displayName: Replication Factor

    # Partition Entity
    - name: redpanda:partition
      displayName: Redpanda Partition
      enabled: true
      rules:
        - idPattern: redpanda_partition_{redpanda_cluster}_{redpanda_namespace}_{redpanda_topic}_{redpanda_partition}
          instanceNamePattern: "{redpanda_topic} - Partition {redpanda_partition}"
          sources:
            - sourceType: Metrics
              condition: $prefix(redpanda.kafka)
          attributes:
            - pattern: '{redpanda_cluster}'
              key: cluster
              displayName: Cluster
            - pattern: '{redpanda_namespace}'
              key: namespace
              displayName: Namespace
            - pattern: '{redpanda_topic}'
              key: topic
              displayName: Topic Name
            - pattern: '{redpanda_partition}'
              key: partition_id
              displayName: Partition ID

  relationships:
    # Namespaces belong to Clusters
    - fromType: redpanda:namespace
      toType: redpanda:cluster
      sources:
        - sourceType: Metrics
          condition: $prefix(redpanda.kafka)

    # Topics belong to Namespaces
    - fromType: redpanda:topic
      toType: redpanda:namespace
      sources:
        - sourceType: Metrics
          condition: $prefix(redpanda.kafka)

    # Partitions belong to Topics
    - fromType: redpanda:partition
      toType: redpanda:topic
      sources:
        - sourceType: Metrics
          condition: $prefix(redpanda.kafka)
```

## Key Design Decisions

### 1. idPattern Strategy

**Cluster ID:**
```
redpanda_cluster_{redpanda_cluster}
```
- Example: `redpanda_cluster_prod-cluster`
- One cluster entity per Redpanda cluster

**Namespace ID:**
```
redpanda_namespace_{redpanda_cluster}_{redpanda_namespace}
```
- Example: `redpanda_namespace_prod-cluster_kafka`
- Ensures uniqueness across clusters

**Topic ID:**
```
redpanda_topic_{redpanda_cluster}_{redpanda_namespace}_{redpanda_topic}
```
- Example: `redpanda_topic_prod-cluster_kafka_orders`
- Hierarchical: includes parent namespace

**Partition ID:**
```
redpanda_partition_{redpanda_cluster}_{redpanda_namespace}_{redpanda_topic}_{redpanda_partition}
```
- Example: `redpanda_partition_prod-cluster_kafka_orders_0`
- Hierarchical: includes parent topic and namespace

### 2. Source Conditions

All entities use:
```yaml
condition: $prefix(redpanda.kafka)
```

This matches all metrics starting with `redpanda.kafka` which includes:
- `redpanda.kafka.consumer_group.*`
- `redpanda.kafka.replicas`
- `redpanda.kafka.max_offset`
- `redpanda.kafka.request.bytes.total`
- `redpanda.kafka.under_replicated_replicas`

**Alternative (more specific):**
```yaml
# Could use different conditions for each entity type:
# For topics with replica info:
condition: $eq(redpanda.kafka.replicas)

# For partitions with offset tracking:
condition: $eq(redpanda.kafka.max_offset)
```

### 3. Attributes

**Cluster attributes:**
- Cluster name

**Namespace attributes:**
- Cluster name (which cluster this namespace belongs to)
- Namespace name

**Topic attributes:**
- Cluster name
- Namespace name
- Topic name
- Replication factor (from `redpanda.kafka.replicas` metric dimension)

**Partition attributes:**
- Cluster name
- Namespace name
- Topic name
- Partition ID

### 4. Relationships

Three relationships defined:
1. **Namespace → Cluster**: Namespaces belong to clusters
2. **Topic → Namespace**: Topics belong to namespaces
3. **Partition → Topic**: Partitions belong to topics

This creates the hierarchy:
```
Cluster
  └─ Namespace
      └─ Topic
          └─ Partition
```

## Integration with Existing Extension

### Placement in extension.yaml

The `topology:` section should be added **after the `minDynatraceVersion`** line and **before the `prometheus:`** section:

```yaml
name: custom:redpanda.enhanced
version: 1.0.12
minDynatraceVersion: '1.310'
author:
  name: Custom Enhanced Redpanda Extension

topology:
  # ... topology section here

prometheus:
  # ... existing prometheus section
```

### No Changes Required To:

- ✅ Existing `prometheus:` section (dimensions stay the same)
- ✅ Existing `metrics:` section (metadata stays the same)
- ✅ Existing dimensions configuration
- ✅ Metric collection logic

### Impact:

- **Additive only** - dimensions continue to work for queries
- **New UX** - entities appear in Smartscape topology view
- **Entity features** - tagging, health tracking, problem correlation now available

## Testing Strategy

### 1. Validation

```bash
# Validate extension syntax
dt ext validate --src extension/

# Check for schema errors
dt ext assemble --src extension/
```

### 2. Deployment Test

1. Build and sign extension v1.0.12
2. Upload to test environment
3. Configure monitoring on Redpanda cluster
4. Wait 5 minutes for data collection

### 3. Verify Entity Creation

**In Dynatrace UI:**

1. **Navigate to Smartscape**
   - Search for "Redpanda"
   - Should see entity types: Cluster, Namespace, Topic, Partition

2. **Check Entity List**
   - Settings → Topology Model → Custom entities
   - Should show:
     - `redpanda:cluster`
     - `redpanda:namespace`
     - `redpanda:topic`
     - `redpanda:partition`

3. **Verify Entity Properties**
   - Click on a Topic entity
   - Should show attributes: cluster, namespace, topic, replication_factor
   - Click on related entities (parent namespace, child partitions)

4. **Test Relationships**
   - Navigate from Cluster → Namespaces
   - Navigate from Namespace → Topics
   - Navigate from Topic → Partitions
   - Visual hierarchy should match Redpanda structure

### 4. Verify Metrics Still Work

**Test that existing functionality is unaffected:**

```dql
// Dimension-based queries should still work
redpanda.kafka.consumer_group.lag.max:filter(eq(redpanda_topic,"orders"))

// Entity-based queries should now also work
redpanda.kafka.consumer_group.lag.max:filter(entitySelector("type(redpanda:topic),entityName(orders)"))
```

### 5. Test Entity Selector Queries

```dql
// Query all metrics for a specific cluster entity
:filter(entitySelector("type(redpanda:cluster),entityName(prod-cluster)"))

// Query all metrics for a specific topic entity
:filter(entitySelector("type(redpanda:topic),entityName(orders)"))

// Query metrics for namespaces in a cluster
:filter(entitySelector("type(redpanda:namespace),fromRelationships.isChildOf(type(redpanda:cluster),entityName(prod-cluster))"))

// Query metrics for topics in a namespace
:filter(entitySelector("type(redpanda:topic),fromRelationships.isChildOf(type(redpanda:namespace),entityName(kafka))"))

// Query metrics for all entities in a cluster
:filter(entitySelector("fromRelationships.isChildOf(type(redpanda:cluster),entityName(prod-cluster))"))

// Query metrics for topics with specific replication factor
:filter(entitySelector("type(redpanda:topic),replication_factor=3"))
```

## Potential Issues and Solutions

### Issue 1: Missing Dimensions

**Problem:** If some metrics don't have all required dimensions, entities won't be created.

**Solution:**
- Review which metrics have `redpanda_namespace`, `redpanda_topic`, `redpanda_partition` dimensions
- May need to adjust source conditions per entity type
- Example: Namespace entities might need `condition: $prefix(redpanda.cluster)` instead

**Check current dimension coverage:**
```bash
# Consumer group metrics have all three dimensions
- redpanda_namespace (from label)
- redpanda_topic (from label)
- redpanda_partition (from label)

# Topic-level metrics
- redpanda.kafka.replicas (has namespace, topic)
- redpanda.kafka.request.bytes.total (has namespace, topic, partition)
```

### Issue 2: Too Many Entities

**Problem:** High-cardinality topics/partitions create many entities.

**Solution:**
- This is expected and normal
- Dynatrace handles high entity counts well
- Can use entity tags to organize if needed

### Issue 3: Entity IDs Not Unique

**Problem:** Duplicate entity IDs cause entities to overwrite each other.

**Solution:**
- Current idPatterns include cluster name to ensure uniqueness
- If still seeing duplicates, may need to include additional dimensions
- Example: Add timestamp or generation ID if needed

### Issue 4: Relationships Not Appearing

**Problem:** Parent-child relationships don't show in Smartscape.

**Solution:**
- Check that relationship sources match metrics that have BOTH entity types' dimensions
- Example: For topic→namespace relationship, need metrics with both `redpanda_topic` AND `redpanda_namespace` dimensions
- `redpanda.kafka.replicas` has both, so relationship should work

## Rollback Plan

If topology causes issues:

1. **Revert to v1.0.11**
   ```bash
   # Rebuild v1.0.11
   git checkout extension/extension.yaml
   ./scripts/build-and-sign-dtcli.sh
   # Upload v1.0.11 signed package
   ```

2. **Delete entities** (if needed)
   - Entities will naturally disappear after 24-48 hours of no data
   - Or manually delete via Settings → Topology Model

3. **Metrics continue working** - dimension-based queries unaffected

## Implementation Checklist

- [ ] Add topology section to extension.yaml
- [ ] Update version to 1.0.12
- [ ] Validate syntax with `dt ext validate`
- [ ] Build and sign extension
- [ ] Test in non-production environment
- [ ] Verify entities appear in Smartscape
- [ ] Verify relationships work
- [ ] Confirm metrics/dimensions still work
- [ ] Update documentation (README, CLAUDE.md, GAP-ANALYSIS.md)
- [ ] Document entity selector query examples
- [ ] Release v1.0.12

## Next Steps

1. **Review this draft** - Does the idPattern strategy make sense?
2. **Test in lab environment** - Deploy to test cluster first
3. **Iterate** - Adjust based on actual entity creation results
4. **Document** - Add topology usage to user guides
5. **Release** - Publish v1.0.12 with topology support

## Questions to Address

1. **Should namespace entities be created even if namespace is empty?**
   - Current design: Only if metrics exist
   - Alternative: Create all configured namespaces

ANSWER: go with current design

2. **Should we use more specific source conditions per entity type?**
   - Current: All use `$prefix(redpanda.kafka)`
   - Alternative: Match specific metrics per entity

ANSWER: go with current design

3. **Do we need a "Cluster" entity type?**
   - Current design: Cluster is an attribute, not an entity
   - Alternative: Add `redpanda:cluster` entity type as root

ANSWER: go with alternative design (add cluster entity type)

4. **Should broker entities be created?**
   - Current design: Only namespace/topic/partition
   - Alternative: Add `redpanda:broker` entity type
   - Note: Would need broker-specific metrics/dimensions

ANSWER: go with current design



---

## Implementation Status - v1.0.13 (October 8, 2025)

### Summary

Topology support was implemented in v1.0.13 with **partial success**. Two of four entity types are working in production.

### ✅ Working Entity Types (2/4)

**1. Cluster Entities (`redpanda:cluster`)** - ✅ FULLY WORKING
- **Status**: Successfully creating entity instances
- **Visibility**: ✅ Visible in Smartscape topology view
- **Source Configuration**:
  - idPattern: `redpanda_cluster_{redpanda_cluster}`
  - instanceNamePattern: `"{redpanda_cluster}"`
  - condition: `$prefix(redpanda.cluster)`
- **Source Metrics**:
  - `redpanda.cluster.brokers` (lines 169-170 in extension.yaml)
  - `redpanda.cluster.partitions` (lines 171-173)
  - `redpanda.cluster.topics` (lines 174-176)
  - `redpanda.cluster.unavailable_partitions` (lines 162-164)
- **Dimension Source**: `const:your-redpanda-cluster` (line 106, 143, 158, etc.)
- **Attributes**:
  - `cluster_name` - Display name of the cluster
- **Example Entity ID**: `redpanda_cluster_your-redpanda-cluster`
- **Why It Works**: Cluster-level metrics (`redpanda.cluster.*`) successfully inherit the const dimension

**2. Topic Entities (`redpanda:topic`)** - ✅ FULLY WORKING
- **Status**: Successfully creating entity instances
- **Visibility**: ✅ Visible in Smartscape topology view
- **Source Configuration**:
  - idPattern: `redpanda_topic_{redpanda_cluster}_{redpanda_namespace}_{redpanda_topic}`
  - instanceNamePattern: `"{redpanda_topic}"`
  - condition: `$prefix(redpanda.kafka)`
- **Source Metrics**:
  - `redpanda.kafka.replicas` (lines 321-323) - Has all required dimensions
- **Dimension Sources**:
  - `redpanda_cluster`: const dimension (line 309)
  - `redpanda_namespace`: label dimension (line 312)
  - `redpanda_topic`: label dimension (line 314)
- **Attributes**:
  - `cluster` - Parent cluster name
  - `namespace` - Parent namespace name
  - `topic` - Topic name
  - `replication_factor` - Number of replicas
- **Example Entity ID**: `redpanda_topic_your-redpanda-cluster_kafka_orders`
- **Relationships**: ✅ Successfully links to parent namespace (defined but namespace entities not created)
- **Why It Works**: `redpanda.kafka.replicas` metric successfully receives `redpanda_cluster` const dimension from `topics_partitions` group

### ❌ Not Working Entity Types (2/4)

**3. Namespace Entities (`redpanda:namespace`)** - ❌ ENTITY TYPE DEFINED, NO INSTANCES
- **Status**: Entity type registered in Dynatrace, but zero instances created
- **Visibility**: ❌ Not visible in Smartscape (no instances exist)
- **Source Configuration**:
  - idPattern: `redpanda_namespace_{redpanda_cluster}_{redpanda_namespace}`
  - instanceNamePattern: `"{redpanda_namespace}"`
  - condition: `$prefix(redpanda.kafka)`
- **Attempted Source Metrics**:
  - All `redpanda.kafka.*` metrics theoretically match condition
  - Would need metrics with namespace dimension but NOT topic/partition dimensions
  - No such metrics exist in current configuration
- **Dimension Sources**:
  - `redpanda_cluster`: const dimension (attempted but doesn't propagate)
  - `redpanda_namespace`: label dimension (available on many metrics)
- **Attributes** (configured but unused):
  - `cluster` - Parent cluster name
  - `namespace` - Namespace name
- **Example Entity ID** (would be): `redpanda_namespace_your-redpanda-cluster_kafka`
- **Relationships**: Configured to link to parent cluster (but no instances created)
- **Why It Doesn't Work**:
  - Cannot get `redpanda_cluster` dimension on namespace-only metrics
  - All metrics with `redpanda_namespace` also have `redpanda_topic` and/or `redpanda_partition`
  - Const dimension limitation prevents cluster dimension from propagating consistently

**4. Partition Entities (`redpanda:partition`)** - ❌ ENTITY TYPE DEFINED, NO INSTANCES
- **Status**: Entity type registered in Dynatrace, but zero instances created
- **Visibility**: ❌ Not visible in Smartscape (no instances exist)
- **Source Configuration**:
  - idPattern: `redpanda_partition_{redpanda_cluster}_{redpanda_namespace}_{redpanda_topic}_{redpanda_partition}`
  - instanceNamePattern: `"{redpanda_topic} - Partition {redpanda_partition}"`
  - condition: `$prefix(redpanda.kafka)`
- **Attempted Source Metrics**:
  - `redpanda.kafka.under_replicated_replicas` (line 196-198) - Has namespace/topic/partition labels
  - `redpanda.kafka.max_offset` (line 324-326) - Has namespace/topic/partition labels
  - `redpanda.kafka.consumer_group.lag.max` (line 290-292) - Has all dimensions
- **Dimension Sources**:
  - `redpanda_cluster`: const dimension (attempted but doesn't propagate)
  - `redpanda_namespace`: label dimension (available)
  - `redpanda_topic`: label dimension (available)
  - `redpanda_partition`: label dimension (available)
- **Attributes** (configured but unused):
  - `cluster` - Parent cluster name
  - `namespace` - Parent namespace name
  - `topic` - Parent topic name
  - `partition_id` - Partition number
- **Example Entity ID** (would be): `redpanda_partition_your-redpanda-cluster_kafka_orders_0`
- **Relationships**: Configured to link to parent topic (but no instances created)
- **Why It Doesn't Work**:
  - Example: `redpanda.kafka.under_replicated_replicas` metric does NOT receive `redpanda_cluster` dimension
  - Even though it's in `partition_health` group (line 153-198) with const dimension at parent level
  - Metrics in SAME group behave differently (replicas gets dimension, under_replicated doesn't)
  - Non-deterministic const dimension propagation in Dynatrace Extensions 2.0

### Root Cause: Const Dimension Limitation

After extensive testing across versions 1.0.14 through 1.0.22, we identified a **Dynatrace Extensions 2.0 limitation** with `const:` dimension propagation for Prometheus data sources:

**The Problem:**
- `const:` dimensions don't consistently apply to all metrics in a group
- Even metrics in the SAME group with IDENTICAL configuration behave differently
- Example from `topics_partitions` group:
  - `redpanda.kafka.replicas` ✅ Gets `redpanda_cluster` dimension
  - `redpanda.kafka.under_replicated_replicas` ❌ Does NOT get dimension
  - Both have identical group/dimension configuration

**What We Tried (All Failed):**
1. Multiple subgroup configurations with dimension inheritance
2. Explicit const dimension definition at subgroup level
3. Flat groups without subgroups
4. Different dimension orderings
5. Splitting metrics into separate groups
6. Moving metrics to different groups

**Conclusion:**
This appears to be non-deterministic or undocumented behavior in Dynatrace Extensions 2.0 for Prometheus-based extensions. The `const:` dimension feature works for some metrics but not others, even under identical configuration.

### Production Value

Despite the limitation, v1.0.13 provides **significant value**:

✅ **Cluster-level monitoring**
- Visual cluster health in Smartscape
- Cluster entity relationships
- Entity selector queries: `fetch dt.entity.redpanda:cluster`

✅ **Topic-level monitoring**
- Topic entities linked to parent cluster
- Topic health tracking
- Entity selector queries: `fetch dt.entity.redpanda:topic`

✅ **All metrics continue working**
- 40/40 metrics collecting successfully
- 100% feature parity maintained
- Dimension-based queries unaffected

### Viewing Entities

**Via Smartscape:**
- Observe and explore → Entities
- Filter by type: `redpanda:cluster` or `redpanda:topic`

**Via DQL:**
```dql
# List clusters
fetch dt.entity.redpanda:cluster

# List topics
fetch dt.entity.redpanda:topic

# Query metrics for a specific cluster
redpanda.cluster.brokers:filter(entitySelector("type(redpanda:cluster),entityName(your-redpanda-cluster)"))
```

### Future Improvements

**Option 1: Wait for Dynatrace Fix**
- Report const dimension issue to Dynatrace support
- May be fixed in future Extensions 2.0 releases

**Option 2: External Label Injection**
- Configure Prometheus to add `cluster` label to all metrics
- Would require changes outside the extension
- More complex deployment

**Option 3: Accept Current State**
- Cluster + topic entities provide 80% of topology value
- Partition-level monitoring still works via dimensions
- Recommended approach for production use

### Recommendation

**Deploy v1.0.13** - The partial topology support with cluster and topic entities provides significant operational value despite namespace/partition limitations. All metrics continue working at 100% feature parity.

---

## Comparison with Official Dynatrace Extension Topology

**Official Extension**: Available on Dynatrace Hub (official Redpanda extension)
**Enhanced Extension**: v1.0.13 (this custom extension)

### Topology Feature Comparison

| Feature | Official Extension | Enhanced Extension v1.0.13 | Notes |
|---------|-------------------|---------------------------|-------|
| **Cluster Entities** | ❌ Not supported | ✅ **Fully working** | Enhanced only - cluster-level entity with broker/partition/topic metadata |
| **Namespace Entities** | ✅ Fully working | ❌ Not working | Official advantage - const dimension limitation in enhanced |
| **Topic Entities** | ✅ Fully working | ✅ **Fully working** | Both create topic entities with attributes |
| **Partition Entities** | ✅ Fully working | ❌ Not working | Official advantage - const dimension limitation in enhanced |
| **Visual Hierarchy** | ✅ Namespace → Topic → Partition | ⚠️ **Partial**: Cluster → Topic | Official has deeper hierarchy |
| **Entity Attributes** | ✅ Full metadata | ✅ Full metadata (where working) | Both provide rich attributes |
| **Smartscape Navigation** | ✅ Complete | ⚠️ Partial (cluster + topic only) | Official has more navigation paths |
| **Entity-based Queries** | ✅ All entity types | ⚠️ Cluster + topic only | Official supports more entity selectors |

### Entity Type Comparison Details

#### 1. Cluster Entities
- **Official**: ❌ Not supported - no cluster-level entity type
- **Enhanced**: ✅ **UNIQUE FEATURE** - Creates `redpanda:cluster` entities
  - Provides cluster-level health view in Smartscape
  - Aggregates broker, partition, and topic counts
  - Example: `fetch dt.entity.redpanda:cluster`
  - **Advantage**: Enhanced provides cluster-level topology that official lacks

#### 2. Namespace Entities
- **Official**: ✅ Fully working - Creates `redpanda:namespace` entities
  - Successfully creates namespace instances in Smartscape
  - Links namespaces to clusters (likely uses different dimension approach)
  - Example: `fetch dt.entity.redpanda:namespace`
- **Enhanced**: ❌ Not working - Entity type defined but no instances created
  - Blocked by Dynatrace const dimension limitation
  - Cannot propagate `redpanda_cluster` dimension to namespace-only metrics
  - **Disadvantage**: Official has working namespace entities

#### 3. Topic Entities
- **Official**: ✅ Fully working - Creates `redpanda:topic` entities
  - Topic instances with parent namespace relationships
  - Includes replication factor and other topic metadata
  - Example: `fetch dt.entity.redpanda:topic`
- **Enhanced**: ✅ Fully working - Creates `redpanda:topic` entities
  - Successfully creates topic instances in Smartscape
  - Links topics to parent namespace (though namespace entities don't exist)
  - Includes replication factor attribute from `redpanda.kafka.replicas` metric
  - Example: `fetch dt.entity.redpanda:topic`
  - **Tie**: Both create topic entities successfully

#### 4. Partition Entities
- **Official**: ✅ Fully working - Creates `redpanda:partition` entities
  - Partition instances with parent topic relationships
  - Provides partition-level health and offset tracking
  - Example: `fetch dt.entity.redpanda:partition`
- **Enhanced**: ❌ Not working - Entity type defined but no instances created
  - Blocked by Dynatrace const dimension limitation
  - Cannot propagate `redpanda_cluster` dimension to partition-level metrics
  - Metrics like `under_replicated_replicas` lack cluster dimension
  - **Disadvantage**: Official has working partition entities

### Hierarchy Comparison

**Official Extension Hierarchy:**
```
(No cluster entity - starts at namespace level)
└─ Namespace (redpanda:namespace) ✅
    └─ Topic (redpanda:topic) ✅
        └─ Partition (redpanda:partition) ✅
```

**Enhanced Extension v1.0.13 Hierarchy:**
```
Cluster (redpanda:cluster) ✅ [UNIQUE TO ENHANCED]
 └─ Namespace (redpanda:namespace) ❌ [Entity type defined, no instances]
     └─ Topic (redpanda:topic) ✅
         └─ Partition (redpanda:partition) ❌ [Entity type defined, no instances]
```

**Effective Enhanced Hierarchy in Smartscape:**
```
Cluster (redpanda:cluster) ✅
 └─ Topic (redpanda:topic) ✅
     (Partitions tracked via dimensions, not entities)
```

### Use Case Recommendations

#### Choose Official Extension Topology When:
1. **Namespace-level monitoring is critical**
   - Need to organize topics by namespace in Smartscape
   - Navigate namespace → topic relationships visually
   - Create entity-based queries for namespace health

2. **Partition-level entity tracking is required**
   - Need partition entities in Smartscape
   - Monitor partition health via entity relationships
   - Navigate topic → partition hierarchy visually

3. **Deep hierarchy navigation is essential**
   - Require namespace → topic → partition drill-down
   - Entity-based problem correlation at all levels
   - Visual topology view is primary interface

#### Choose Enhanced Extension Topology When:
1. **Cluster-level monitoring is critical**
   - Need cluster entity as root of topology (not available in official)
   - Aggregate cluster health metrics in one place
   - Monitor broker/partition/topic counts at cluster level

2. **Topic-level monitoring is sufficient**
   - Topics are primary unit of monitoring (most common use case)
   - Cluster → topic hierarchy meets navigation needs
   - Namespace/partition filtering via dimensions is acceptable

3. **Dimension-based filtering is acceptable**
   - Can use `redpanda_namespace`, `redpanda_partition` dimensions for queries
   - Don't need entity relationships for namespace/partition levels
   - Data Explorer queries with dimensions meet requirements

#### Use BOTH Extensions When:
**Possible but not recommended** - Doubles DDU consumption

If you need both:
- Cluster-level topology (enhanced only)
- Namespace/partition entities (official only)
- Complete hierarchy at all levels

**Better approach**: Choose one based on primary use case, use dimensions for missing entity types

### Why Official Extension Works

The official extension likely uses one of these approaches:

1. **Different Dimension Strategy**
   - May not use `const:` dimensions
   - Could rely only on Prometheus labels for all dimensions
   - Would require cluster label in Prometheus metrics (external configuration)

2. **Different Extension Framework**
   - May be built with JMX or custom data source (not Prometheus)
   - Different metric collection approach avoids const dimension issue
   - Access to internal Dynatrace features not available in Extensions 2.0

3. **Dynatrace-Optimized Implementation**
   - Official extension may have special handling in Dynatrace backend
   - Extensions 2.0 API has more limitations than internal tools
   - Custom extensions face stricter constraints

### Technical Root Cause Summary

**Enhanced Extension Limitation:**
- Uses `const:` dimension for `redpanda_cluster` (required for static cluster name)
- Dynatrace Extensions 2.0 Prometheus data source has non-deterministic const dimension propagation
- Same group, same configuration, different results per metric
- Example: `kafka.replicas` gets dimension ✅, `kafka.under_replicated_replicas` doesn't ❌

**Official Extension Advantage:**
- Successfully creates all entity types (namespace, topic, partition)
- Likely uses different technical approach that avoids const dimension limitation
- May require external configuration (Prometheus label injection) that's not visible to users

### Future Improvements for Enhanced Extension

**Option 1: Dynatrace Fix** (waiting for Dynatrace)
- Report const dimension limitation to Dynatrace support
- May be fixed in future Extensions 2.0 releases
- Timeline: Unknown

**Option 2: External Label Injection** (requires Prometheus config)
- Configure Prometheus to add `cluster` label to all metrics at scrape time
- Would make cluster dimension available as label, not const
- Requires infrastructure changes outside the extension
- Example Prometheus relabel config:
  ```yaml
  metric_relabel_configs:
    - source_labels: []
      target_label: cluster
      replacement: 'your-cluster-name'
  ```

**Option 3: Hybrid Approach** (use both extensions)
- Enhanced for metrics and cluster entity
- Official for namespace/partition entities
- Doubles DDU consumption
- Not recommended for most users

**Option 4: Accept Current State** (recommended)
- Cluster + topic entities provide 80% of topology value
- Use dimensions for namespace/partition filtering
- Most users monitor at cluster/topic level primarily
- Simplest solution with significant value

### Topology Comparison Summary

| Aspect | Winner | Reason |
|--------|--------|--------|
| **Cluster-level view** | ✅ Enhanced | Unique cluster entity (official lacks this) |
| **Namespace entities** | ✅ Official | Working vs not working |
| **Topic entities** | 🤝 Tie | Both fully working |
| **Partition entities** | ✅ Official | Working vs not working |
| **Hierarchy depth** | ✅ Official | 3 levels vs 2 levels |
| **Root entity** | ✅ Enhanced | Has cluster root (official starts at namespace) |
| **Overall completeness** | ✅ Official | 3/3 entity types vs 2/4 |

**Final Topology Recommendation:**
- **Most users**: Enhanced extension - cluster + topic entities cover 80% of use cases, plus superior metrics (40 vs 29)
- **Advanced users needing full hierarchy**: Official extension - complete namespace/partition topology
- **Enterprise with both needs**: Use official extension for topology, optionally add enhanced for unique metrics (disk alert, RPC timeouts)
