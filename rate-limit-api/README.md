
# Rate Limit ConfigMap API

API REST para listar, adicionar e remover regras do ConfigMap de rate limit do Istio/Envoy em Kubernetes.

## Funcionalidades
- Listagem de regras com índice (`id`) para fácil remoção
- Adição de regras com validação para evitar duplicidade de `key`+`value`
- Remoção de regras por índice
- Rollout automático do deployment do serviço de rate limit após alterações

## Como rodar localmente
1. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   ```
2. Exporte variáveis de ambiente se necessário (opcional):
   - `RATE_LIMIT_NAMESPACE` (default: istio-system)
   - `RATE_LIMIT_CONFIGMAP` (default: ratelimit-config)
   - `RATE_LIMIT_CONFIGMAP_KEY` (default: ping-pong.yaml)
3. Execute o serviço:
   ```bash
   uvicorn main:app --reload
   ```

## Build da imagem Docker
```bash
docker build -t <seu-usuario>/rate-limit-api:latest .
```

## Deploy no Kubernetes
1. Edite os manifests em `manifests/` conforme necessário (imagem, namespace, etc)
2. Aplique os manifests:
   ```bash
   kubectl apply -f manifests/sa.yaml
   kubectl apply -f manifests/deployment.yaml
   kubectl apply -f manifests/service.yaml
   ```

## Endpoints
- `GET /rules` — Lista todas as regras (com campo `id`)
- `POST /rules` — Adiciona uma nova regra (JSON do descriptor)
- `DELETE /rules/{id}` — Remove a regra pelo índice

### Exemplo de payload para adicionar:
```json
{
  "key": "client_id",
  "value": "novo_cliente",
  "rate_limit": { "unit": "minute", "requests_per_unit": 42 }
}
```

### Exemplo de resposta de listagem:
```json
[
  {
    "id": 0,
    "key": "client_id",
    "value": "gold",
    "rate_limit": { "unit": "minute", "requests_per_unit": 100 }
  },
  ...
]
```

## Observações
- Não permite duplicidade de regras com mesmo `key`+`value`.
- Regras sem `value` (ex: apenas `detailed_metric`) não entram na checagem de duplicidade.
- Após qualquer alteração, o deployment do serviço de rate limit é reiniciado automaticamente para aplicar a nova configuração.
- Para rodar no cluster, a ServiceAccount precisa de permissão para `get`, `list`, `patch` em ConfigMaps e `patch` em Deployments.

## Segurança
Considere proteger a API (ex: autenticação, RBAC, rede) em ambientes produtivos.
