# Manifestos Kubernetes — kube-news

Aplicados pelo `make apps` do [labs-k8s](https://github.com/fabricioveronez/labs-k8s),
que substitui a tag da imagem pelo short SHA do commit corrente deste repositório
antes do `kubectl apply`.

| Arquivo | Conteúdo |
|---|---|
| `00-namespace.yaml` | namespace `kube-news` |
| `10-postgres.yaml` | Secret, Service headless e StatefulSet do PostgreSQL 16 |
| `20-configmap.yaml` | configuração de conexão consumida por `envFrom` |
| `30-app.yaml` | Service, Deployment e Ingress |
| `40-seed.yaml` | ConfigMap com os 8 artigos e Job que os posta |
| `50-observability.yaml` | ServiceMonitor e PrometheusRule |
| `60-traffic.yaml` | gerador de tráfego contínuo |

## Detalhes que não são óbvios

**A porta 8080 é hardcoded.** `src/server.js` faz `app.listen(8080)` e nunca lê
`process.env.PORT`. O `ENV PORT=8080` do Dockerfile é decorativo — mudá-lo não muda nada.

**Uma réplica só.** O schema nasce de `sequelize.sync({ alter: true })` no boot, que
emite DDL a cada start de cada réplica. Com N réplicas subindo juntas, elas disputam o
mesmo `ALTER`.

**O ConfigMap existe para tornar a falha ruidosa.** Todas as variáveis de banco têm
default hardcoded em `src/models/post.js` (`DB_HOST` cai em `localhost`), então sem o
ConfigMap a aplicação *sobe* e falha em silêncio tentando conectar em si mesma.
Consumido por `envFrom`, um ConfigMap ausente trava o pod em
`CreateContainerConfigError`, com o motivo escrito no evento.

**O seed não é idempotente.** A app não verifica duplicata. O Job tem nome fixo
justamente por isso: `kubectl apply` repetido não o reexecuta. Para recarregar,
apague o Job antes.

**Endpoints de caos.** `PUT /unreadyfor/<segundos>` faz `/ready` devolver 500 pelo
período. `PUT /unhealth` liga um middleware global que passa a devolver 500 em **toda**
rota, `/health` inclusive, e **não tem como reverter** — só reiniciando o pod.
