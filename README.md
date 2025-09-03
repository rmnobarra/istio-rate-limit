
# Istio Rate Limiting Project

Este projeto tem como objetivo implementar e demonstrar uma solução de rate limiting (limitação de requisições) utilizando Istio e Envoy em um ambiente Kubernetes. O rate limiting é fundamental para proteger APIs e serviços contra abusos, controlar o tráfego e garantir a disponibilidade dos recursos.

## Propósito
- Proteger aplicações expostas via Istio Gateway contra excesso de requisições.
- Demonstrar como configurar filtros Envoy para aplicar políticas de rate limiting baseadas em identificadores de cliente (por exemplo, cabeçalho `X-Client-Id`).
- Fornecer exemplos práticos de configuração, implantação e testes de rate limiting em Istio.

## Estrutura do Projeto
- [`rate-limit/`](./rate-limit/): Contém todos os manifestos YAML, scripts e exemplos necessários para configurar e testar o rate limiting no Istio.

## Como usar
1. Siga as instruções do README dentro da pasta [`rate-limit/`](./rate-limit/) para aplicar as configurações no seu cluster Kubernetes com Istio instalado.
2. Utilize os exemplos fornecidos para validar o funcionamento do rate limiting.

## Requisitos
- Kubernetes
- Istio instalado no cluster
- Permissões para aplicar recursos no namespace `istio-system`

Para detalhes de configuração e execução, consulte o [README da pasta rate-limit](./rate-limit/README.md).

