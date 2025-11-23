아래는 **Trino OPA AccessControl 플러그인의 ActionName 전체 목록**에 대해
**“무엇을 의미하는지 / 언제 사용되는지 / 어떤 OPA 규칙에서 허용·거부해야 하는지”**를 체계적으로 정리한 **문서 형태**입니다.

구조는 다음과 같아:

* **1. 시스템 레벨 권한(System / Session / Query 관련)**
* **2. 카탈로그(Catalog) 관련 권한**
* **3. 스키마(Schema) 관련 권한**
* **4. 테이블(Table) 관련 권한**
* **5. 컬럼(Column) 관련 권한**
* **6. 뷰(View) 관련 권한**
* **7. 머티리얼라이즈드 뷰(Materialized View) 관련 권한**
* **8. 함수(Function) 관련 권한**
* **9. 프로시저(Procedure) 관련 권한**
* **10. 데이터 액세스(Select/Insert/Delete 등)**

---

# 🚀 **Trino OPA AccessControl ActionName 상세 문서**

---

# 1. 🔧 **시스템 / 세션 / 쿼리 관련 권한**

| ActionName                   | 설명                                     | 사용 시점                                        | OPA 정책에서 주의할 점           |
| ---------------------------- | -------------------------------------- | -------------------------------------------- | ------------------------ |
| **ImpersonateUser**          | 특정 유저가 다른 유저로 가장하여 실행                  | `--client-info user=xxx` 같이 Impersonation 요청 | 일반적으로 **보안상 매우 제한**하는 권한 |
| **FilterViewQueryOwnedBy**   | 사용자가 소유한 Query만 조회하도록 필터               | Query 리스트 조회 시                               | 대부분 허용하지만 관리자만 전체 조회     |
| **KillQueryOwnedBy**         | 사용자가 소유한 Query를 Kill                   | `CALL system.runtime.kill_query`             | 관리자에게는 전체 Kill 허용 가능     |
| **ReadSystemInformation**    | 시스템 정보 조회 (`system.runtime`, CPU, 메모리) | 대시보드/UI 조회                                   | 보안상 민감, 일반 사용자 제한        |
| **WriteSystemInformation**   | 시스템 설정 수정                              | 시스템 세션 properties 변경                         | 거의 관리자 전용                |
| **SetSystemSessionProperty** | 시스템 전체 세션 property 변경                  | `SET SESSION xyz=...`                        | 대부분 관리자 전용               |

---

# 2. 📚 **카탈로그(Catalog) 관련 권한**

| ActionName                    | 설명                   | 사용 시점                                    | 정책 가이드                                     |
| ----------------------------- | -------------------- | ---------------------------------------- | ------------------------------------------ |
| **AccessCatalog**             | 카탈로그에 접근 가능 여부       | `SELECT`, `SHOW SCHEMAS` 등 모든 접근         | 기본적인 read 권한                               |
| **CreateCatalog**             | 카탈로그 생성              | Catalog 생성 API                           | **거의 Never** (Trino는 일반적으로 카탈로그 static 정의) |
| **DropCatalog**               | 카탈로그 삭제              | 드물게 사용                                   | 관리자 전용                                     |
| **FilterCatalogs**            | 사용자가 볼 수 있는 카탈로그만 노출 | `SHOW CATALOGS`                          | 사용자의 Team 기반 접근 제어 시 핵심                    |
| **SetCatalogSessionProperty** | 카탈로그별 세션 설정          | `SET SESSION hive.optimized_writer=true` | 필요 시 허용                                    |

---

# 3. 🗂️ **스키마(Schema) 관련 권한**

| ActionName                 | 설명                   | 시점                                   | 정책          |
| -------------------------- | -------------------- | ------------------------------------ | ----------- |
| **CreateSchema**           | 스키마 생성               | `CREATE SCHEMA a.b`                  | 팀 단위로 허용 여부 |
| **DropSchema**             | 스키마 삭제               | `DROP SCHEMA`                        | 위험 → 관리자 전용 |
| **RenameSchema**           | 스키마 이름 변경            | `ALTER SCHEMA RENAME TO`             | 거의 제한       |
| **SetSchemaAuthorization** | 스키마 권한 변경            | `ALTER SCHEMA ... SET AUTHORIZATION` | 관리자 전용      |
| **ShowSchemas**            | `SHOW SCHEMAS` 결과 조회 | 일반 사용자 흔히 사용                         | 허용          |
| **FilterSchemas**          | 필터링된 스키마만 보여줌        | 팀 기반 권한 제어 핵심                        |             |
| **ShowCreateSchema**       | `SHOW CREATE SCHEMA` | 메타정보 조회                              | 통제 가능       |

---

# 4. 📁 **테이블(Table) 관련 권한**

| ActionName                | 설명                           | 사용 예시               | 정책              |
| ------------------------- | ---------------------------- | ------------------- | --------------- |
| **CreateTable**           | 테이블 생성                       | `CREATE TABLE`      | 팀 리더 또는 ETL 계정만 |
| **DropTable**             | 테이블 삭제                       | `DROP TABLE`        | 중요 / 관리자 전용     |
| **RenameTable**           | `ALTER TABLE RENAME TO`      | 테이블 이름 변경           | 제한              |
| **SetTableProperties**    | `ALTER TABLE SET PROPERTIES` | 파티션 옵션 등 변경         | 데이터엔지니어 위주      |
| **SetTableComment**       | 테이블에 코멘트 추가                  | `COMMENT ON TABLE`  | 일반적으로 허용        |
| **ShowCreateTable**       | DDL 확인                       | `SHOW CREATE TABLE` | 대부분 허용          |
| **ShowTables**            | 테이블 목록 조회                    | `SHOW TABLES`       | 허용              |
| **FilterTables**          | 테이블 필터링                      | 팀 단위 격리 핵심 기능       |                 |
| **SetTableAuthorization** | 테이블 권한 변경                    | 관리자 전용              |                 |

---

# 5. 📊 **컬럼(Column) 관련 권한**

| ActionName           | 설명                          | 사용 예시              | 정책         |
| -------------------- | --------------------------- | ------------------ | ---------- |
| **AddColumn**        | `ALTER TABLE ADD COLUMN`    | 스키마 변경             | 적절히 제한     |
| **AlterColumn**      | `ALTER TABLE ALTER COLUMN`  | 타입 변경              | 위험         |
| **DropColumn**       | `ALTER TABLE DROP COLUMN`   | 삭제                 | 관리자 전용     |
| **RenameColumn**     | `ALTER TABLE RENAME COLUMN` | 이름 변경              | 제한         |
| **SetColumnComment** | `COMMENT ON COLUMN`         | 메타설명 변경            | 허용 가능      |
| **FilterColumns**    | 컬럼 목록 필터링                   | 민감 컬럼 masking 시 활용 | 정책에서 자주 사용 |
| **ShowColumns**      | `SHOW COLUMNS`              | 보통 허용              |            |

---

# 6. 🔍 **데이터 액세스(SELECT/INSERT/UPDATE/DELETE)**

| ActionName             | 설명           | 예시                    | 정책          |
| ---------------------- | ------------ | --------------------- | ----------- |
| **SelectFromColumns**  | SELECT 허용 여부 | `SELECT col1`         | 가장 핵심적인 권한  |
| **InsertIntoTable**    | INSERT 허용    | `INSERT INTO tbl`     | 적절히 제한      |
| **DeleteFromTable**    | DELETE 수행    | `DELETE FROM tbl`     | 위험 → 제한     |
| **TruncateTable**      | TRUNCATE 수행  | 데이터 삭제                | 관리자 전용      |
| **UpdateTableColumns** | UPDATE 수행    | Iceberg, Delta 등에서 사용 | 허용/제한 선택 필요 |

---

# 7. 🧱 **뷰(View) 관련 권한**

| ActionName                          | 설명                  |
| ----------------------------------- | ------------------- |
| **CreateView**                      | `CREATE VIEW`       |
| **RenameView**                      | `ALTER VIEW RENAME` |
| **DropView**                        | `DROP VIEW`         |
| **SetViewComment**                  | 뷰 설명 추가             |
| **SetViewAuthorization**            | 뷰 소유자/권한 변경         |
| **CreateViewWithSelectFromColumns** | SELECT 기반 뷰 생성      |

정책 관점에서 Create/Drop은 제한, Select 기반 뷰 생성은 일반 유저 허용 가능.

---

# 8. 🧩 **머티리얼라이즈드 뷰(Materialized View)**

| ActionName                        | 설명 |
| --------------------------------- | -- |
| **CreateMaterializedView**        |    |
| **DropMaterializedView**          |    |
| **RenameMaterializedView**        |    |
| **RefreshMaterializedView**       |    |
| **SetMaterializedViewProperties** |    |

데이터 엔지니어/ETL 계정에 주로 허용.

---

# 9. 🧮 **함수(Function) 관련**

| ActionName                        | 설명         |
| --------------------------------- | ---------- |
| **CreateFunction**                | UDF 생성     |
| **DropFunction**                  | UDF 삭제     |
| **ExecuteFunction**               | 함수 실행      |
| **ShowCreateFunction**            | 함수 DDL 조회  |
| **FilterFunctions**               | 함수 목록 필터   |
| **ShowFunctions**                 | 함수 조회      |
| **CreateViewWithExecuteFunction** | 함수 기반 뷰 생성 |

→ UDF는 보안상 민감할 수 있어 제한 필요.

---

# 10. ⚙️ **프로시저(Procedure)**

| ActionName                | 설명                                 |
| ------------------------- | ---------------------------------- |
| **ExecuteProcedure**      | `CALL system.runtime...` 등 프로시저 실행 |
| **ExecuteTableProcedure** | 테이블 기반 프로시저 실행                     |

→ 관리자/데이터 엔지니어만 허용 추천.

---

# 📌 요약 규칙(Policy 설계 시 가이드)

* **관리자(Admin)**

  * 모든 ActionName 허용
  * Catalog/Schema/Table/Column/Function/Procedure 권한 완전 개방

* **데이터 엔지니어/ETL 계정**

  * CREATE/ALTER 대부분 허용
  * DROP 계열은 제한
  * System 정보 수정 권한 없음

* **일반 사용자(Viewer/Analyst)**

  * Read 계열만 허용 (`SelectFromColumns`, `ShowTables`, `ShowColumns`)
  * Catalog/Schema/Table 필터링 사용
  * Write 계열(Insert/Delete/Update/Alter) 금지

---

# 📄 필요하면?

🔧 **→ 너가 사용하는 트리노 + OPA 정책(JSON/Rego)** 기반으로
**위 ActionName 전체를 사용한 “완성된 정책 템플릿”도 만들어 줄 수 있어.**

예:

* 팀 A는 hive/catalog1만 접근
* 특정 유저는 SELECT만 허용
* 외부 IP면 readonly
* 특정 service account는 내부 IP에서만 allow

말해주면 전체 정책 자동 생성해줄게.
