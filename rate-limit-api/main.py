
from fastapi import FastAPI, HTTPException, Path, Body
from fastapi.responses import JSONResponse
from kubernetes import client, config
import yaml
import os

NAMESPACE = os.environ.get("RATE_LIMIT_NAMESPACE", "istio-system")
CONFIGMAP_NAME = os.environ.get("RATE_LIMIT_CONFIGMAP", "ratelimit-config")
CONFIGMAP_KEY = os.environ.get("RATE_LIMIT_CONFIGMAP_KEY", "ping-pong.yaml")


app = FastAPI(
        title="Rate Limit ConfigMap API",
        description="""
API para gerenciar regras de rate limit do Istio/Envoy via ConfigMap Kubernetes.

## Exemplos de uso

### Adicionar regra
POST /rules
```json
{
    "key": "client_id",
    "value": "gold",
    "rate_limit": { "unit": "minute", "requests_per_unit": 100 }
}
```

### Remover regra
DELETE /rules/0

### Listar regras
GET /rules
```
[
    {
        "key": "client_id",
        "value": "gold",
        "rate_limit": { "unit": "minute", "requests_per_unit": 100 }
    },
    ...
]
```
""",
        version="1.0.0"
)

# Carrega config do cluster (dentro ou fora)
try:
    config.load_incluster_config()
except Exception:
    config.load_kube_config()

k8s = client.CoreV1Api()

def get_configmap():
    return k8s.read_namespaced_config_map(CONFIGMAP_NAME, NAMESPACE)


def update_configmap(data):
    body = {"data": {CONFIGMAP_KEY: data}}
    k8s.patch_namespaced_config_map(CONFIGMAP_NAME, NAMESPACE, body)

def rollout_restart_deployment(deployment_name: str, namespace: str):
    """
    Executa rollout restart do deployment (atualiza annotation para forçar restart dos pods)
    """
    apps = client.AppsV1Api()
    from datetime import datetime
    now = datetime.utcnow().isoformat()
    body = {
        "spec": {
            "template": {
                "metadata": {
                    "annotations": {
                        "kubectl.kubernetes.io/restartedAt": now
                    }
                }
            }
        }
    }
    apps.patch_namespaced_deployment(
        name=deployment_name,
        namespace=namespace,
        body=body
    )



@app.get("/rules", summary="Listar regras", response_description="Lista de regras atuais", tags=["Regras"])
def list_rules():
    """
    Retorna todas as regras (descriptors) do ConfigMap, cada uma com seu índice (id).
    """
    cm = get_configmap()
    raw = cm.data.get(CONFIGMAP_KEY, "")
    doc = yaml.safe_load(raw)
    rules = doc.get("descriptors", [])
    # Adiciona o índice como 'id' em cada regra
    return [dict(id=i, **rule) for i, rule in enumerate(rules)]


@app.post(
    "/rules",
    summary="Adicionar regra",
    response_description="Status da operação",
    tags=["Regras"],
    response_model=dict,
    responses={
        200: {
            "content": {
                "application/json": {
                    "example": {"status": "ok"}
                }
            }
        }
    },
)
def add_rule(
    rule: dict = Body(
        ...,
        example={
            "key": "client_id",
            "value": "gold",
            "rate_limit": {"unit": "minute", "requests_per_unit": 100}
        },
        description="Descriptor de rate limit a ser adicionado."
    )
):
    """
    Adiciona uma nova regra (descriptor) ao ConfigMap e reinicia o deployment do rate limit.
    Não permite duplicidade de key+value.
    """
    cm = get_configmap()
    doc = yaml.safe_load(cm.data.get(CONFIGMAP_KEY, ""))
    descriptors = doc.setdefault("descriptors", [])
    # Validação: não permitir duplicidade de key+value (apenas se value estiver presente)
    new_key = rule.get("key")
    new_value = rule.get("value")
    if new_value is not None:
        for desc in descriptors:
            # Só compara se ambos têm value
            if desc.get("key") == new_key and desc.get("value") == new_value:
                raise HTTPException(400, f"Já existe uma regra com key={new_key} e value={new_value}.")
    descriptors.append(rule)
    new_yaml = yaml.dump(doc, sort_keys=False)
    update_configmap(new_yaml)
    rollout_restart_deployment("ratelimit", NAMESPACE)
    return {"status": "ok"}


@app.delete(
    "/rules/{idx}",
    summary="Remover regra",
    response_description="Status da operação",
    tags=["Regras"],
    response_model=dict,
    responses={
        200: {
            "content": {
                "application/json": {
                    "example": {"status": "ok"}
                }
            }
        },
        404: {
            "description": "Regra não encontrada"
        }
    },
)
def delete_rule(
    idx: int = Path(..., description="Índice da regra a ser removida (começa em 0)", example=0)
):
    """
    Remove uma regra (descriptor) pelo índice na lista e reinicia o deployment do rate limit.
    """
    cm = get_configmap()
    doc = yaml.safe_load(cm.data.get(CONFIGMAP_KEY, ""))
    try:
        doc["descriptors"].pop(idx)
    except Exception:
        raise HTTPException(404, "Regra não encontrada")
    new_yaml = yaml.dump(doc, sort_keys=False)
    update_configmap(new_yaml)
    rollout_restart_deployment("ratelimit", NAMESPACE)
    return {"status": "ok"}
