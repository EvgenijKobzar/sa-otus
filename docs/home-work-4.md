## 1. Модель функциональной декомпозиции
Выбор модели функциональной декомпозиции — Service-Oriented Architecture (SOA) зафиксирован в 
[ADR-10](architecture/decisions/0010-service-oriented-architecture.md)

## 2. Доменные границы и сервисы 
Доменные границы и сервисы определены в [ADR-11](architecture/decisions/0011-domain-boundaries-and-services.md)

### 2.1 Каталог доменов и сервисов
| Домен                    | Сервисы                                                             | Основные сущности (SSOT)                      | Бизнес-цель                          |  Владелец                          |
| ------------------------ | ------------------------------------------------------------------- | --------------------------------------------- | ------------------------------------ |------------------------------------|
| **Identity & Customer**  | Auth, Users, Privacy                                                | User, Role, Session, Plan, Consent            | Безопасность, персонализация         |  Team Identity                     |
| **Content & Documents**  | Templates, Docs, Preview/Render, Storage (абстракция)               | Template, Document, Version, Preview, BlobRef | Создание/редактирование/хранение     |  Team Content                      |
| **Printing & Execution** | PrintOrders, Scheduling, Stores, PrintGateway                       | PrintOrder, Job, Slot, Store, Device          | Выполнение печати                    |  Team Print                        |
| **Finance & Payments**   | Billing, Payments, Invoicing                                        | Quote, Tariff, Payment, Subscription, Invoice | Монетизация, расчёты                 |  Team Finance                      |
| **Communication & CX**   | Notifications, Feedback                                             | Notification, Channel, Template, Feedback     | Своеврем. коммуникация, NPS          |  Team CX                           |
| **Operations & Data**    | Reporting, Audit/Compliance, Observability, Config/Flags, OpsBridge | AuditEvent, Metric, Report, Flag              | Управляемость, комплаенс, интеграции |  Team Platform                     |

### 2.2 Связи между доменами
| Источник                    | Цель                           | Тип взаимодействия | Пример                    |
| --------------------------- | ------------------------------ | ------------------ | ------------------------- |
| **Content → Printing**      | Передача документа на печать   | API (sync)         | Создание заказа на печать |
| **Printing → Finance**      | Инициация оплаты               | API (sync)         | Оплата печати             |
| **Finance → Communication** | Отправка уведомления об оплате | Event (async)      | Пуш-уведомление           |
| **Content → Operations**    | Логирование изменений          | Event (async)      | Аналитика                 |
| **Identity → Finance**      | Проверка тарифа/лимита         | API (sync)         | Расчёт цены               |
| **Operations → All**        | Сбор метрик, аудит             | Event consumer     | Наблюдаемость             |

### 2.3 Диаграмма иерархии уровней

```mermaid
graph TD
  SYS["Система: Платформа печати"]

  subgraph D1["Identity & Customer"]
    AUTH(Auth)
    USERS(Users)
    PRIV(Privacy)
  end

  subgraph D2["Content & Documents"]
    DOC(Docs)
    TPL(Templates)
    PREV(Preview)
    STOR[(Storage)]
  end

  subgraph D3["Printing & Execution"]
    ORD(PrintOrders)
    SCH(Scheduling)
    PG(PrintGateway)
    STR(Stores)
  end

  subgraph D4["Finance & Payments"]
    BILL(Billing)
    PAY(Payments)
    INV(Invoicing)
  end

  subgraph D5["Communication & CX"]
    NOTIF(Notifications)
    FB(Feedback)
  end

  subgraph D6["Operations & Data"]
    RPT(Reporting)
    AUD(Audit)
    OBS(Observability)
    CFG(Config)
  end

  SYS --> D1
  SYS --> D2
  SYS --> D3
  SYS --> D4
  SYS --> D5
  SYS --> D6

  D2 --> D3
  D3 --> D4
  D4 --> D5
  D2 --> D6
  D3 --> D6
  D4 --> D6
  D1 --> D4
  D1 --> D2

```

## 3. Диаграмма C4 (Container level)

### 3.1. C4 Container Diagram с доменами (верхнеуровнево)
```mermaid
C4Container
    title C4 Diagram (Container Level): Платформа создания и печати документов

    Person(customer, "Пользователь", "Создаёт, редактирует и печатает документы")
    System_Ext(stripe, "Stripe / Adyen", "Платёжные провайдеры")
    System_Ext(email, "SMTP / SMS Gateway", "Отправка уведомлений")
    System_Ext(store, "Физические копи-центры", "Принимают задания на печать")

    Boundary(identity, "Домен: Identity & Customer") {
        Container(auth, "Auth API", "Spring Boot", "Авторизация и токены JWT")
        Container(users, "Users Service", "Node.js", "Управление профилями пользователей и тарифами")
        ContainerDb(usersDb, "Users DB", "PostgreSQL", "Профили, роли, тарифы")
    }

    Boundary(content, "Домен: Content & Documents") {
        Container(docs, "Docs API", "FastAPI", "Создание и редактирование документов")
        Container(preview, "Preview Worker", "Python Worker", "Генерация предпросмотров")
        ContainerDb(contentDb, "Docs DB", "PostgreSQL", "Документы и версии")
        Container(storage, "Object Storage", "S3", "Хранение файлов")
    }

    Boundary(printing, "Домен: Printing & Execution") {
        Container(printOrders, "PrintOrders API", "Java", "Управление заказами на печать")
        Container(printGateway, "Print Gateway", "Go", "Адаптеры к физическим принтерам")
        ContainerDb(printDb, "Print DB", "PostgreSQL", "Заказы, статусы, слоты")
    }

    Boundary(finance, "Домен: Finance & Payments") {
        Container(billing, "Billing API", "Kotlin", "Расчёт стоимости услуг")
        Container(payments, "Payments Service", "Python", "Интеграция с провайдерами")
        ContainerDb(finDb, "Finance DB", "PostgreSQL", "Платежи, счета, тарифы")
    }

    Boundary(communication, "Домен: Communication & CX") {
        Container(notif, "Notifications Service", "NestJS", "Отправка уведомлений клиентам")
    }

    Boundary(operations, "Домен: Operations & Data") {
        Container(audit, "Audit Service", "Rust", "Хранение событий и логов аудита")
        Container(report, "Reporting Service", "Python", "Сбор аналитики")
    }

    Rel(customer, auth, "Логин / регистрация")
    Rel(customer, docs, "Создаёт документ")
    Rel(docs, printOrders, "Передаёт задание на печать")
    Rel(printOrders, billing, "Запрос расчёта стоимости")
    Rel(billing, payments, "Выставляет счёт на оплату")
    Rel(payments, stripe, "Оплата")
    Rel(payments, notif, "Отправка уведомления")
    Rel(printOrders, store, "Передача задания в физическую точку")
    Rel(docs, audit, "Запись действий")

```

### 3.2. C4 (Container level) сервисы, технологии и ключевые взаимодействия
```mermaid
flowchart LR
  %% --- External actors/systems ---
  user([Пользователь<br/>Web/Mobile])
  extPay([Платёжные провайдеры<br/>Stripe/Adyen/CloudPayments])
  extMail([Email/SMS Gateway])
  physStore([Физические копи-центры<br/>принтеры/киоски])

  %% --- Identity & Customer ---
  subgraph D1["Домен: Identity & Customer"]
    AUTH["Auth API<br/>(Spring Boot, OAuth/OIDC)"]
    USERS["Users Service<br/>(Node.js, REST)"]
    UDB[("Users DB<br/>PostgreSQL")]
    AUTH --- UDB
    USERS --- UDB
  end

  %% --- Content & Documents ---
  subgraph D2["Домен: Content & Documents"]
    DOCS["Docs API<br/>(FastAPI)"]
    TPL["Templates Service<br/>(Go)"]
    PREV["Preview/Render Worker<br/>(Python Workers)"]
    CDB[("Docs DB<br/>PostgreSQL")]
    OBJ[("Object Storage<br/>S3-compatible")]
    DOCS --- CDB
    DOCS --- OBJ
    PREV --- OBJ
  end

  %% --- Printing & Execution ---
  subgraph D3["Домен: Printing & Execution"]
    ORD["PrintOrders API<br/>(Java/Spring)"]
    SCH["Scheduling Service<br/>(Kotlin)"]
    PG["Print Gateway (Adapters)<br/>(Go)"]
    STORES["Stores Service<br/>(Rust)"]
    PDB[("Printing DB<br/>PostgreSQL")]
    ORD --- PDB
    SCH --- PDB
    PG --- PDB
    STORES --- PDB
  end

  %% --- Finance & Payments ---
  subgraph D4["Домен: Finance & Payments"]
    BILL["Billing API<br/>(Kotlin)"]
    PAY["Payments Facade<br/>(Python/FastAPI)"]
    FINDB[("Finance DB<br/>PostgreSQL")]
    BILL --- FINDB
    PAY --- FINDB
  end

  %% --- Communication & CX ---
  subgraph D5["Домен: Communication & CX"]
    NOTIF["Notifications Service<br/>(NestJS)"]
    CXDB[("Comm DB<br/>PostgreSQL")]
    NOTIF --- CXDB
  end

  %% --- Operations & Data ---
  subgraph D6["Домен: Operations & Data"]
    RPT["Reporting/Analytics<br/>(Python ETL)"]
    AUD["Audit/Compliance<br/>(Rust)"]
    OBS["Observability<br/>(Prometheus/Grafana/OTel)"]
    CFG["Config/Feature Flags<br/>(Go)"]
    BUS[["Event Bus<br/>(Kafka/NATS)"]]
  end

  %% --- API Gateway / BFF (edge) ---
  GW["API Gateway / BFF<br/>(NGINX/Node BFF)"]

  %% --- Client entry points ---
  user -->|HTTPS| GW
  GW --> AUTH
  GW --> USERS
  GW --> DOCS
  GW --> TPL
  GW --> ORD
  GW --> BILL
  GW --> PAY
  GW --> NOTIF
  GW --> STORES
  GW --> SCH

  %% --- Cross-domain sync calls ---
  DOCS -->|REST: создать заказ печати| ORD
  ORD -->|REST: запрос котировки| BILL
  BILL -->|REST: инициировать оплату| PAY
  PAY -->|REST/Webhooks| extPay
  PAY -->|event: Payment.Succeeded| BUS
  ORD -->|event: PrintOrder.*| BUS
  DOCS -->|event: Docs.VersionCreated| BUS
  NOTIF -->|SMTP/SMS| extMail

  %% --- Event subscriptions ---
  BUS --> NOTIF
  BUS --> RPT
  BUS --> AUD

  %% --- Printing path to physical world ---
  ORD -->|REST: StartJob| PG
  PG -->|LAN/IPPS/Driver| physStore

  %% --- Content storage & preview flow ---
  DOCS -. presigned URL .-> OBJ
  PREV <-->|events/jobs| BUS

  %% --- Observability & Config (platform cross-cutting) ---
  AUTH -. metrics/logs .-> OBS
  DOCS -. traces/metrics .-> OBS
  ORD -. traces/metrics .-> OBS
  BILL -. metrics .-> OBS
  PAY  -. metrics .-> OBS
  NOTIF -. metrics .-> OBS
  CFG --> AUTH
  CFG --> DOCS
  CFG --> ORD
  CFG --> BILL
  CFG --> PAY
  CFG --> NOTIF

```
## 4. Декомпозиция слоя данных: какие данные в каких БД хранятся

| Домен/Сервис           | Тип БД/Хранилище      | Что хранится                                 |
| ---------------------- |-----------------------| -------------------------------------------- |
| Auth/Users             | PostgreSQL, Redis     | учётки, профили, планы; сессии/блок-листы    |
| Docs                   | PostgreSQL            | метаданные документов/версий/шаринга         |
| Docs Blobs             | S3                    | двоичные данные версий, предпросмотры        |
| Templates              | PostgreSQL + S3       | метаданные и артефакты шаблонов              |
| Search                 | OpenSearch            | полнотекст по документам                     |
| PrintOrders/Jobs/Slots | PostgreSQL            | заказы, задания, расписания, устройства      |
| Device telemetry       | Timescale/ClickHouse  | метрики принтеров (TS)                       |
| Billing/Payments       | PostgreSQL            | тарифы, котировки, статусы платежей, инвойсы |
| Reconciliation         | S3                    | отчёты провайдера, свёрка                    |
| Notifications/Feedback | PostgreSQL, Redis     | сообщения, шаблоны, скоринг, квоты           |
| Event Bus              | Kafka/NATS            | доменные события (ретенция)                  |
| Warehouse              | ClickHouse/Snowflake  | аналитика и отчётность (факты/измерения)     |
| Audit/Compliance       | S3 (WORM), OpenSearch | неизменяемый аудит, поисковый индекс         |
| Observability          | Prometheus/Loki/Tempo | метрики, логи, трейсы                        |
| Config/Flags           | Consul/Postgres       | конфигурации и фичефлаги                     |

## 5. Деплоймент диаграмма
### 5.1. Прод: облако + регионы + внешние системы
```mermaid
flowchart LR
%% ==== External users/systems ====
    user[[Пользователь<br/>Web/Mobile]]
    extPay[[Платёжные провайдеры<br/>Stripe/Adyen/РУ-провайдер]]
    extMail[[Email/SMS Gateway]]
    extIdp[[Corp/3rd-party IdP]]

%% ==== Global Edge ====
    subgraph EDGE["Global Edge"]
        CDN[(CDN)]
        WAF[WAF / DDoS]
    end
    user --> CDN --> WAF

%% ==== Cloud Region ====
    subgraph CLOUD["Cloud Region: prod-eu-central (VPC)"]
        subgraph NET["Private Subnets / Security Groups"]
            subgraph K8S["Kubernetes Cluster (prod)"]
                subgraph NS_ID["ns: identity"]
                    AUTH["Auth API (Deployment)"]
                    USERS["Users Service (Deployment)"]
                end
                subgraph NS_CONTENT["ns: content"]
                    DOCS["Docs API (Deployment)"]
                    PREV["Preview Workers (HPA)"]
                    TPL["Templates API (Deployment)"]
                end
                subgraph NS_PRINT["ns: printing"]
                    ORD["PrintOrders API (Deployment)"]
                    PG["PrintGateway (DaemonSet/Adapters)"]
                    SCH["Scheduling API (Deployment)"]
                end
                subgraph NS_FIN["ns: finance"]
                    BILL["Billing API (Deployment)"]
                    PAY["Payments Facade (Deployment)"]
                    INV["Invoicing API (Deployment)"]
                end
                subgraph NS_CX["ns: cx"]
                    NOTIF["Notifications (Deployment)"]
                end
                subgraph NS_PLAT["ns: platform"]
                    GW["API Gateway / BFF (Ingress)"]
                    OBS["Observability Agents (DaemonSet)"]
                    SIDECAR["Sidecar: OTel/Envoy (per pod)"]
                end
            end

            subgraph DATA["Managed Data Services (HA/Backup)"]
                UDB[(Users DB<br/>PostgreSQL)]
                CDB[(Docs DB<br/>PostgreSQL)]
                PDB[(Printing DB<br/>PostgreSQL)]
                FDB[(Finance DB<br/>PostgreSQL)]
                CXDB[(Comm DB<br/>PostgreSQL)]
                OBJ[(Object Storage<br/>S3-compatible)]
                BUS[(Event Bus<br/>Kafka/NATS)]
                AUDDB[(Audit Store<br/>WORM/S3-Glacier)]
                METRICS[(TSDB / Logs<br/>Prometheus/Loki)]
                CFG[(Config/Flags<br/>Consul/Redis)]
            end
        end
    end

%% ==== Connectivity ====
    WAF --> GW
    GW --> AUTH & USERS & DOCS & ORD & BILL & PAY & NOTIF & SCH & TPL
    PREV --> OBJ
    DOCS --- OBJ
    PG -.->|IPSec/VPN| STORE_EDGE

%% ==== Data links ====
    AUTH --- UDB
    USERS --- UDB
    DOCS --- CDB
    ORD --- PDB
    SCH --- PDB
    BILL --- FDB
    PAY --- FDB
    NOTIF --- CXDB

%% ==== Platform links ====
    AUTH -. metrics/logs .-> METRICS
    DOCS -. metrics/logs .-> METRICS
    ORD  -. metrics/logs .-> METRICS
    BILL -. metrics/logs .-> METRICS
    PAY  -. metrics/logs .-> METRICS
    NOTIF -. metrics/logs .-> METRICS
    GW -. config .-> CFG
    BUS -. persist .-> OBJ
%%   AUDDB <-. archive .- METRICS

%% ==== External systems ====
    PAY -- webhook/callback --> extPay
    NOTIF --> extMail
    AUTH --- extIdp

%% ==== Edge stores placeholder ====
    STORE_EDGE[[Магазины Edge sites<br/>см. отдельную схему]]

```
### 5.2. Магазин (edge site): печать и связь с продом
```mermaid
flowchart LR
  subgraph STORE["Edge Site: Магазин #123 (LAN)"]
    subgraph NETS["Local Network / VLANs"]
      KIOSK[Киоск для клиентов iPad/PC]
      POS[POS-терминал оплаты]
      PRN1[[Принтер #1]]
      PRN2[[Принтер #2]]
      GWEDGE[Edge Gateway<br/> Docker/Agent]
      CACHE[(Edge Cache / Queue)]
    end
  end

  subgraph CLOUD["Cloud Region (prod)"]
    PG[PrintGateway Cluster]
%%    ORD[PrintOrders API]
    PAY[Payments Facade]
%%    BUS[(Event Bus)]
  end

  %% Connectivity
  KIOSK -->|HTTPS| CLOUD
  POS -->|Payment app/MPOS| PAY
  GWEDGE <-->|MQTT/gRPC over mTLS| PG
  GWEDGE -->|Spool/IPPS| PRN1
  GWEDGE -->|Spool/IPPS| PRN2
  GWEDGE --- CACHE
%%  ORD <-->|events| BUS
  GWEDGE -. telemetry .-> CLOUD
  GWEDGE -. VPN/IPSec .- CLOUD

```
>Локальный агент в магазине (GWEDGE)
поддерживает защищённое (mTLS) соединение с облачным шлюзом печати (PG)
и обменивается данными через протоколы MQTT и gRPC.
>
>Через это соединение облако отправляет задания на печать,
а агент передаёт статусы и метрики принтеров.
