# Runbook: Convolens PostgreSQL Database Migration

**Task Reference:** Baton Subtask 4 (`cabf4190-aefc-499c-a690-5d9b504bcaa6`)  
**Parent Migration:** `ad65f8ed-bab4-46eb-bdb4-3bea4bb2837e`  
**Governing ADRs:** [ADR 0002: Shared Data Plane Ownership](../adr/0002-shared-data-plane-ownership.md), [ADR 0004: HOV as NexaMesh Product](../adr/0004-hov-nexamesh-product-boundary.md)

---

## 1. Scope and Boundaries

- **Database:** `convolens`
- **Source Environment:**
  - Subscription: `bb4e3882-2079-4bab-8974-611bc0b8bb58` (`mystira-sub`)
  - Server: `nl-prod-shared-pg.postgres.database.azure.com` (PostgreSQL 16, South Africa North)
  - Database Name: `convolens`
  - Tenant Role: `convolens`
- **Destination Environment:**
  - Subscription: `5a95ddee-dd63-441a-8306-c8b0803dcdd4` (`neuralliquid-sub`)
  - Server: `nl-prod-data-pg.postgres.database.azure.com` (PostgreSQL 16, South Africa North)
  - Database Name: `convolens`
  - Tenant Role: `convolens`

> [!IMPORTANT]
> **Strict HOV Exclusion Policy:**
> Per ADR 0004 and task `37547ca3`, the `houseofveritas` database and all HOV assets remain completely untouched on `mystira-sub`. HOV is classified as a NexaMesh physical-estate product and will be migrated to an isolated datastore in `nex-prod-hov-rg` under `nexamesh-sub` (`8a5dc70a-bafa-4a04-a281-9b4862a70810`). Do NOT dump, export, or modify HOV data during this procedure.

---

## 2. Pre-Migration Prerequisites

1. **Target Infrastructure Verification:**
   - Terraform stack `infra/terraform/shared-data` applied in `neuralliquid-sub`.
   - Target server `nl-prod-data-pg`, resource group `nl-prod-shared-rg`, and database `convolens` exist.
   - Key Vault `nl-prod-shared-kv` provisioned with admin credentials stored at `postgres-admin-password`.

2. **Network & Firewall Access:**
   - Define an IP-scoped, session-safe rule name:
     ```bash
     export OPERATOR_IP=$(curl -s https://api.ipify.org)
     export RULE_NAME="MigrationTempRunner_$(echo "$OPERATOR_IP" | tr '.' '_')"
     ```
   - Add operator/runner IP temporarily to source and target servers:
     ```bash
     # Source server (mystira-sub)
     az postgres flexible-server firewall-rule create \
       --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
       --resource-group nl-prod-shared-rg \
       --server-name nl-prod-shared-pg \
       --rule-name "$RULE_NAME" \
       --start-ip-address "$OPERATOR_IP" \
       --end-ip-address "$OPERATOR_IP"

     # Target server (neuralliquid-sub)
     az postgres flexible-server firewall-rule create \
       --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
       --resource-group nl-prod-shared-rg \
       --server-name nl-prod-data-pg \
       --rule-name "$RULE_NAME" \
       --start-ip-address "$OPERATOR_IP" \
       --end-ip-address "$OPERATOR_IP"
     ```

3. **Secrets Retrieval:**
   - Retrieve source admin password:
     ```bash
     SOURCE_PG_ADMIN_PW=$(az keyvault secret show \
       --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
       --vault-name nl-prod-shared-kv \
       --name postgres-admin-password \
       --query value -o tsv)
     ```
   - Retrieve target admin password:
     ```bash
     TARGET_PG_ADMIN_PW=$(az keyvault secret show \
       --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
       --vault-name nl-prod-shared-kv \
       --name postgres-admin-password \
       --query value -o tsv)
     ```
   - Retrieve Convolens role password:
     ```bash
     CONVOLENS_ROLE_PW=$(az keyvault secret show \
       --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
       --vault-name nl-prod-convolens-kv \
       --name convolens-db-password \
       --query value -o tsv)
     ```

4. **Client Tooling:**
   - PostgreSQL client utilities (`pg_dump`, `pg_restore`, `psql`) version 16.x installed.

---

## 3. Migration Procedure

### Phase 1: Source Quiescence & Baseline Validation
1. Enable maintenance mode or scale down Convolens runtime (`nl-prod-convolens-web`) to prevent live writes during export:
   ```bash
   az webapp stop \
     --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
     --resource-group nl-prod-convolens-rg \
     --name nl-prod-convolens-web
   ```
2. Capture baseline table record counts on source database:
   ```sql
   -- Run on source database convolens
   SELECT schemaname, relname, n_live_tup
   FROM pg_stat_user_tables
   ORDER BY schemaname, relname;
   ```

### Phase 2: Database Backup / Export (`pg_dump`)
1. Run `pg_dump` targeting ONLY the `convolens` database on source server `nl-prod-shared-pg`:
   ```bash
   PGPASSWORD="$SOURCE_PG_ADMIN_PW" pg_dump \
     -h nl-prod-shared-pg.postgres.database.azure.com \
     -U nlsharedadmin \
     -d convolens \
     --format=custom \
     --compress=9 \
     --verbose \
     --file=convolens_migration_$(date +%Y%m%d_%H%M%S).dump
   ```
2. Generate and verify SHA256 checksum:
   ```bash
   sha256sum convolens_migration_*.dump > convolens_migration.sha256
   cat convolens_migration.sha256
   ```
3. Retain backup archive in secure storage / blob container as a rollback baseline.

### Phase 3: Target Role and Database Setup
1. Connect as `nlsharedadmin` to target server `nl-prod-data-pg` in `neuralliquid-sub`:
   ```sql
   -- Connect: psql -h nl-prod-data-pg.postgres.database.azure.com -U nlsharedadmin -d postgres
   -- Create product tenant login role
   CREATE ROLE convolens WITH LOGIN PASSWORD '<CONVOLENS_ROLE_PW>';

   -- Assign ownership of database
   ALTER DATABASE convolens OWNER TO convolens;
   GRANT ALL PRIVILEGES ON DATABASE convolens TO convolens;

   -- Switch to convolens database
   \c convolens

   -- Assign schema ownership and secure tenant boundary
   GRANT ALL ON SCHEMA public TO convolens;
   ALTER SCHEMA public OWNER TO convolens;

   -- CRITICAL: Prevent cross-tenant database access
   REVOKE CONNECT ON DATABASE convolens FROM PUBLIC;
   GRANT CONNECT ON DATABASE convolens TO convolens;
   ```

### Phase 4: Database Restore (`pg_restore`)
1. Restore schema and data into target `convolens` database on destination server `nl-prod-data-pg`:
   ```bash
   PGPASSWORD="$TARGET_PG_ADMIN_PW" pg_restore \
     -h nl-prod-data-pg.postgres.database.azure.com \
     -U nlsharedadmin \
     -d convolens \
     --no-owner \
     --role=convolens \
     --clean \
     --if-exists \
     --verbose \
     convolens_migration_*.dump
   ```

### Phase 5: Data Integrity Verification
1. Compare table and row counts between source and target:
   ```sql
   SELECT schemaname, relname, n_live_tup
   FROM pg_stat_user_tables
   ORDER BY schemaname, relname;
   ```
2. Verify table count, view count, and sequence numbers:
   ```sql
   SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';
   SELECT count(*) FROM information_schema.sequences WHERE sequence_schema = 'public';
   ```
3. Test read/write functionality with the tenant role `convolens` via transactional DML:
   ```bash
   PGPASSWORD="$CONVOLENS_ROLE_PW" psql \
     -h nl-prod-data-pg.postgres.database.azure.com \
     -U convolens \
     -d convolens \
     -c "
       SELECT current_user, current_database();
       BEGIN;
       CREATE TEMP TABLE _migration_test_rw (id serial PRIMARY KEY, note text);
       INSERT INTO _migration_test_rw (note) VALUES ('validation_probe');
       SELECT * FROM _migration_test_rw;
       ROLLBACK;
     "
   ```
4. Verify tenant isolation:
   - Ensure role `convolens` cannot access any other database or public schema.

### Phase 6: Application Secret & Service Cutover
1. Update Convolens database connection string in `nl-prod-convolens-kv`:
   ```bash
   az keyvault secret set \
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
     --vault-name nl-prod-convolens-kv \
     --name "database-url" \
     --value "postgresql://convolens:<PASSWORD>@nl-prod-data-pg.postgres.database.azure.com:5432/convolens?sslmode=require"
   ```
2. Start Convolens runtime in `neuralliquid-sub` (Subtask 5).
3. Validate application health endpoint:
   ```bash
   curl -I https://convolens.neuralliquid.ai/health
   ```

### Phase 7: Cleanup

1. Remove temporary operator firewall rules for the specific operator IP (preserves concurrent migration/recovery sessions):
   ```bash
   export OPERATOR_IP="${OPERATOR_IP:-$(curl -s https://api.ipify.org)}"

   # Clean up target server firewall rule matching current operator IP
   TARGET_RULES=$(az postgres flexible-server firewall-rule list \
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
     --resource-group nl-prod-shared-rg \
     --server-name nl-prod-data-pg \
     --query "[?startIpAddress=='$OPERATOR_IP' && starts_with(name, 'MigrationTempRunner')].name" -o tsv)

   for r in $TARGET_RULES; do
     echo "Deleting target temporary firewall rule: $r (IP: $OPERATOR_IP)"
     az postgres flexible-server firewall-rule delete \
       --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
       --resource-group nl-prod-shared-rg \
       --server-name nl-prod-data-pg \
       --name "$r" \
       --yes
   done

   # Clean up source server firewall rule matching current operator IP
   SOURCE_RULES=$(az postgres flexible-server firewall-rule list \
     --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
     --resource-group nl-prod-shared-rg \
     --server-name nl-prod-shared-pg \
     --query "[?startIpAddress=='$OPERATOR_IP' && starts_with(name, 'MigrationTempRunner')].name" -o tsv)

   for r in $SOURCE_RULES; do
     echo "Deleting source temporary firewall rule: $r (IP: $OPERATOR_IP)"
     az postgres flexible-server firewall-rule delete \
       --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
       --resource-group nl-prod-shared-rg \
       --server-name nl-prod-shared-pg \
       --name "$r" \
       --yes
   done
   ```

2. Confirm zero temporary rules remain on both target and source servers (both outputs must be empty):
   ```bash
   echo "=== Verifying target server cleanup (should be empty) ==="
   az postgres flexible-server firewall-rule list \
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
     --resource-group nl-prod-shared-rg \
     --server-name nl-prod-data-pg \
     --query "[?startIpAddress=='$OPERATOR_IP'].name" -o tsv

   echo "=== Verifying source server cleanup (should be empty) ==="
   az postgres flexible-server firewall-rule list \
     --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
     --resource-group nl-prod-shared-rg \
     --server-name nl-prod-shared-pg \
     --query "[?startIpAddress=='$OPERATOR_IP'].name" -o tsv
   ```

---

## 4. Rollback Plan

If restore verification fails or application anomalies occur prior to final signoff:
1. Stop the target Convolens workload.
2. Revert `nl-prod-convolens-web` configuration to point back to the source database `nl-prod-shared-pg` on `mystira-sub`.
3. Restart source `nl-prod-convolens-web` on `mystira-sub`.
4. The source `convolens` and `houseofveritas` databases on `mystira-sub` remain completely intact with zero data loss.
