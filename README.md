
# Istio Rate Limiting Project

Este projeto tem como objetivo implementar e demonstrar uma solução de rate limiting (limitação de requisições) utilizando Istio e Envoy em um ambiente Kubernetes. O rate limiting é fundamental para proteger APIs e serviços contra abusos, controlar o tráfego e garantir a disponibilidade dos recursos.

## Propósito
- Proteger aplicações expostas via Istio Gateway contra excesso de requisições.
- Demonstrar como configurar filtros Envoy para aplicar políticas de rate limiting baseadas em identificadores de cliente (por exemplo, cabeçalho `X-Client-Id`).
- Fornecer exemplos práticos de configuração, implantação e testes de rate limiting em Istio.


## Estrutura do Projeto
- [`rate-limit/`](./rate-limit/): Manifestos YAML, scripts e exemplos para configurar e testar o rate limiting no Istio.
- [`rate-limit-api/`](./rate-limit-api/): API REST para gerenciar as regras do ConfigMap de rate limit (listar, adicionar, remover regras) de forma dinâmica no cluster Kubernetes.


## Como usar
1. Siga as instruções do README dentro da pasta [`rate-limit/`](./rate-limit/) para aplicar as configurações no seu cluster Kubernetes com Istio instalado.
2. Utilize os exemplos fornecidos para validar o funcionamento do rate limiting.
3. (Opcional) Use a [`rate-limit-api`](./rate-limit-api/) para gerenciar as regras de rate limit via API REST, sem editar YAML manualmente. Veja instruções detalhadas no README da pasta.

## Requisitos
- Kubernetes
- Istio instalado no cluster
- Istioctl
- Permissões para aplicar recursos no namespace `istio-system`

Para detalhes de configuração e execução, consulte o [README da pasta rate-limit](./rate-limit/README.md) e o [README da rate-limit-api](./rate-limit-api/README.md).

