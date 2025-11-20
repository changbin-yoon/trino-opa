#!/bin/bash

# Trino OPA 서비스 계정 접근 제어 테스트 스크립트
# 사용법: ./trino-opa-service-account-test.sh [OPA_SERVER_URL]

OPA_SERVER=${1:-http://localhost:8181}
POLICY_PATH="v1/data/trino/allow"

echo "=========================================="
echo "Trino OPA 서비스 계정 접근 제어 테스트"
echo "OPA Server: $OPA_SERVER"
echo "=========================================="
echo ""

# 테스트 1: 서비스 계정이 Kubernetes 환경에서 접근 (성공)
echo "테스트 1: 서비스 계정이 Kubernetes 환경에서 접근 (예상: 허용)"
RESULT=$(curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "svc-trino-reader",
          "groups": ["service-accounts", "team-a"]
        },
        "source": {
          "ip": "10.0.1.100"
        }
      },
      "action": {
        "type": "QueryAccessControl"
      }
    }
  }')
echo "$RESULT" | jq '.'
ALLOW=$(echo "$RESULT" | jq -r '.result.allow // false')
if [ "$ALLOW" = "true" ]; then
  echo "✅ 테스트 통과"
else
  echo "❌ 테스트 실패 (예상: true, 실제: $ALLOW)"
fi
echo ""

# 테스트 2: 서비스 계정이 외부 환경에서 접근 (실패)
echo "테스트 2: 서비스 계정이 외부 환경에서 접근 (예상: 거부)"
RESULT=$(curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "svc-trino-reader",
          "groups": ["service-accounts"]
        },
        "source": {
          "ip": "203.0.113.50"
        }
      },
      "action": {
        "type": "QueryAccessControl"
      }
    }
  }')
echo "$RESULT" | jq '.'
ALLOW=$(echo "$RESULT" | jq -r '.result.allow // false')
if [ "$ALLOW" = "false" ]; then
  echo "✅ 테스트 통과"
else
  echo "❌ 테스트 실패 (예상: false, 실제: $ALLOW)"
fi
echo ""

# 테스트 3: 일반 사용자가 서비스 계정 이름 패턴 사용 시도 (실패)
echo "테스트 3: 일반 사용자가 서비스 계정 이름 패턴 사용 시도 (예상: 거부)"
RESULT=$(curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "svc-malicious-user",
          "groups": ["team-a"]
        }
      },
      "action": {
        "type": "QueryAccessControl"
      }
    }
  }')
echo "$RESULT" | jq '.'
ALLOW=$(echo "$RESULT" | jq -r '.result.allow // false')
if [ "$ALLOW" = "false" ]; then
  echo "✅ 테스트 통과"
else
  echo "❌ 테스트 실패 (예상: false, 실제: $ALLOW)"
fi
echo ""

# 테스트 4: 일반 사용자가 정상 접근 (성공)
echo "테스트 4: 일반 사용자가 정상 접근 (예상: 허용)"
RESULT=$(curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
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
  }')
echo "$RESULT" | jq '.'
ALLOW=$(echo "$RESULT" | jq -r '.result.allow // false')
if [ "$ALLOW" = "true" ]; then
  echo "✅ 테스트 통과"
else
  echo "❌ 테스트 실패 (예상: true, 실제: $ALLOW)"
fi
echo ""

# 테스트 5: 세션 속성으로 Kubernetes 환경 지정 (성공)
echo "테스트 5: 세션 속성으로 Kubernetes 환경 지정 (예상: 허용)"
RESULT=$(curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "svc-trino-writer",
          "groups": ["service-accounts"]
        },
        "session": {
          "environment": "kubernetes"
        }
      },
      "action": {
        "type": "QueryAccessControl"
      }
    }
  }')
echo "$RESULT" | jq '.'
ALLOW=$(echo "$RESULT" | jq -r '.result.allow // false')
if [ "$ALLOW" = "true" ]; then
  echo "✅ 테스트 통과"
else
  echo "❌ 테스트 실패 (예상: true, 실제: $ALLOW)"
fi
echo ""

# 테스트 6: 서비스 계정이 Kubernetes 환경에서 스키마 접근 (성공)
echo "테스트 6: 서비스 계정이 Kubernetes 환경에서 스키마 접근 (예상: 허용)"
RESULT=$(curl -s -X POST "$OPA_SERVER/$POLICY_PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "context": {
        "identity": {
          "user": "svc-analytics",
          "groups": ["service-accounts"]
        },
        "source": {
          "ip": "10.0.2.50"
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
  }')
echo "$RESULT" | jq '.'
ALLOW=$(echo "$RESULT" | jq -r '.result.allow // false')
if [ "$ALLOW" = "true" ]; then
  echo "✅ 테스트 통과"
else
  echo "❌ 테스트 실패 (예상: true, 실제: $ALLOW)"
fi
echo ""

echo "=========================================="
echo "테스트 완료"
echo "=========================================="

