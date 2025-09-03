
# Rate Limiting com Istio

Este diretório contém um exemplo completo de implementação de rate limiting (limitação de requisições) utilizando Istio, Envoy e Redis em um cluster Kubernetes. O objetivo é proteger APIs expostas via Istio Gateway, controlando o tráfego por cliente (ex: via cabeçalho `X-Client-Id`).

## Estrutura dos arquivos
- `01.gateway.yaml`: Configuração do Gateway Istio.
- `02.configmap.yaml`: ConfigMap com as regras de rate limit.
- `03.redis.yaml`: Implantação do Redis para armazenamento dos contadores de rate limit.
- `04.rate-limit-service.yaml`: Serviço de rate limit (gRPC) compatível com Envoy.
- `05.filter.yaml`: Filtro Envoy para integração do rate limit.
- `06.rules.yaml`: Regras de rate limit aplicadas ao VirtualHost.
- `ping-pong.yaml`: Exemplo de configuração de regras para o serviço de teste.
- `script.sh`: Script para testar e validar o funcionamento do rate limit.

## Passo a passo para implantação

### 1. Instale o metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

**Se estiver usando kind, minikube, etc:**
```bash
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

### 2. Instale o Istio e o Gateway API (se necessário)
```bash
istioctl install --set profile=default -y

kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
```

### 3. Instale o Prometheus (opcional, para monitoramento)
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheusOperator.enabled=true \
  --set kubeStateMetrics.enabled=false \
  --set nodeExporter.enabled=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
```

### 4. Crie os namespaces das aplicações
```bash
kubectl create namespace ping-pong-app-01
kubectl create namespace ping-pong-app-02
```

### 5. Habilite o sidecar injection do Istio nos namespaces
```bash
kubectl label namespace ping-pong-app-01 istio-injection=enabled
kubectl label namespace ping-pong-app-02 istio-injection=enabled
```

### 6. Instale as workloads de exemplo
```bash
kubectl apply -f https://raw.githubusercontent.com/rmnobarra/ping-pong-app/refs/heads/main/ping-pong-app.yaml -n ping-pong-app-01
kubectl apply -f https://raw.githubusercontent.com/rmnobarra/ping-pong-app/refs/heads/main/ping-pong-app.yaml -n ping-pong-app-02
```

### 7. Instale o Gateway
```bash
kubectl apply -f 01.gateway.yaml
```

### 8. Instale o ConfigMap de rate limit
```bash
kubectl apply -f 02.configmap.yaml
```

### 9. Instale o Redis
```bash
kubectl apply -f 03.redis.yaml
```

### 10. Instale o serviço de rate limit
```bash
kubectl apply -f 04.rate-limit-service.yaml
```

### 11. Instale o filtro Envoy
```bash
kubectl apply -f 05.filter.yaml
```

### 12. Instale as regras de rate limit
```bash
kubectl apply -f 06.rules.yaml
```

### 13. Valide a instalação
```bash
kubectl get virtualservices.networking.istio.io -A
kubectl get gateways.networking.istio.io -A
kubectl get servicemonitors.monitoring.coreos.com -A
kubectl get crd virtualservices.networking.istio.io gateways.networking.istio.io servicemonitors.monitoring.coreos.com
```

### 14. Teste o rate limit
```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80
```
**Em outro terminal:**

```bash
GW=127.0.0.1:8080
curl -H "Host: example.com" http://$GW/health
```

Execute:
```bash
./script.sh
```

O script irá simular requisições de diferentes clientes e validar se os limites estão sendo respeitados. O output esperado é semelhante a:

```bash
gold     | burst     | total=105  200=100  429=5    other=0   
silver   | burst     | total=55   200=50   429=5    other=0   
bronze   | burst     | total=25   200=20   429=5    other=0   
user-abc | burst     | total=15   200=10   429=5    other=0   
```

---

Para dúvidas ou sugestões, consulte o README principal do projeto ou abra uma issue.