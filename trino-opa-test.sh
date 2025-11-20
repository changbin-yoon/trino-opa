#!/bin/bash

# Trino OPA 정책 테스트 스크립트
# 사용법: ./trino-opa-test.sh [OPA_SERVER_URL]

OPA_SERVER=${1:-http://localhost:8181}
POLICY_PATH="v1/data/trino/allow"

echo "=========================================="
echo "Trino OPA 정책 테스트"
echo "OPA Server: $OPA_SERVER"
echo "=========================================="
echo ""

# 테스트 1: team-a 사용자가 hive.team_a_schema 접근 허용
echo "테스트 1: team-a 사용자가 hive.team_a_schema 접근 허용"
curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "alice",
          "groups": ["team-a"]
        }
      },
      "action": {
        "type": "SchemaAccessControl",
        "catalog": "hive",
        "schema": {
          "catalog": "hive",
          "schema": "team_a_schema"
        }
      }
    }
  }' | jq '.'
echo ""

# 테스트 2: team-a 사용자가 hive.team_b_schema 접근 거부
echo "테스트 2: team-a 사용자가 hive.team_b_schema 접근 거부"
curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "alice",
          "groups": ["team-a"]
        }
      },
      "action": {
        "type": "SchemaAccessControl",
        "catalog": "hive",
        "schema": {
          "catalog": "hive",
          "schema": "team_b_schema"
        }
      }
    }
  }' | jq '.'
echo ""

# 테스트 3: team-b 사용자가 iceberg.team_b_schema 접근 허용
echo "테스트 3: team-b 사용자가 iceberg.team_b_schema 접근 허용"
curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "bob",
          "groups": ["team-b"]
        }
      },
      "action": {
        "type": "SchemaAccessControl",
        "catalog": "iceberg",
        "schema": {
          "catalog": "iceberg",
          "schema": "team_b_schema"
        }
      }
    }
  }' | jq '.'
echo ""

# 테스트 4: admin 그룹 사용자가 모든 스키마 접근 허용
echo "테스트 4: admin 그룹 사용자가 모든 스키마 접근 허용"
curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "admin",
          "groups": ["admin"]
        }
      },
      "action": {
        "type": "SchemaAccessControl",
        "catalog": "hive",
        "schema": {
          "catalog": "hive",
          "schema": "any_schema"
        }
      }
    }
  }' | jq '.'
echo ""

# 테스트 5: 공유 스키마 접근 허용
echo "테스트 5: team-a 사용자가 team_shared_schema 접근 허용"
curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "alice",
          "groups": ["team-a"]
        }
      },
      "action": {
        "type": "SchemaAccessControl",
        "catalog": "hive",
        "schema": {
          "catalog": "hive",
          "schema": "team_shared_schema"
        }
      }
    }
  }' | jq '.'
echo ""

echo "=========================================="
echo "테스트 완료"
echo "=========================================="

