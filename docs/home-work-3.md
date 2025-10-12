## You Look Good In Print

### 1. Сервис **PrintOrders** (заказы на печать).

 Что делает PrintOrders

* Принимает/хранит заказы печати, параметры (цвет, двусторонняя, формат), слот времени и магазин.
* Считает цену (через сервис Billing), инициирует оплату (через сервис Payments).
* После оплаты отправляет задание в печать (через сервис PrintGateway) и отслеживает статусы.
* Шлёт события для уведомлений и аналитики.

---

# Взаимодействие (критичный сценарий: «Оформление и выполнение заказа»)

```mermaid
sequenceDiagram
  autonumber
  participant UI as Web/Mobile UI
  participant APIGW as API Gateway
  participant ORD as PrintOrders
  participant BILL as Billing
  participant PAY as Payments
  participant DOC as Docs (presigned)
  participant STOR as Object Storage
  participant PG as PrintGateway
  participant NOTIF as Notifications
  participant BUS as Event Bus

  UI->>APIGW: POST /print-orders {docId, storeId, params, slot}
  APIGW->>ORD: Create(orderDraft)
  ORD->>BILL: Quote(orderDraft, userTier)
  BILL-->>ORD: {amount, currency}
  ORD-->>APIGW: {orderId, quote}
  APIGW-->>UI: Показать цену

  UI->>APIGW: POST /print-orders/{id}/confirm {paymentMethod}
  APIGW->>ORD: Confirm(orderId)
  ORD->>PAY: CreatePayment(orderId, amount, method, idempotencyKey)
  PAY-->>ORD: {paymentId, clientSecret}
  ORD-->>APIGW: {paymentId, clientSecret}
  APIGW-->>UI: Завершить оплату (SDK/3DS)

  PAY-->>ORD: (event) Payment.Succeeded {orderId}
  ORD->>DOC: GET assetUrl (pre-signed) by docId
  DOC->>STOR: Generate pre-signed (read)
  STOR-->>DOC: assetUrl
  DOC-->>ORD: assetUrl

  ORD->>PG: StartJob(orderId, assetUrl, params, storeId)
  PG-->>ORD: (event) Print.JobStarted {orderId}
  PG-->>ORD: (event) Print.JobCompleted {orderId, pages, duration}

  ORD-->>BUS: PrintOrder.ReadyForPickup {orderId}
  BUS-->>NOTIF: Route
  NOTIF-->>UI: "Заказ готов к выдаче"
  ORD-->>APIGW: GET /print-orders/{id} → status=ReadyForPickup
```

---

# Оценка архитектурного решения (по атрибутам качества)

## 1) Надёжность / согласованность

* **Сценарий:** платёж прошёл, а отправка в печать временно недоступна.
* **Механизмы:** outbox + ретраи; оркестрация саги (статусы: `Paid → Dispatching → Printing → Ready`); идемпотентные команды `StartJob(orderId)`.
* **Ожидаемо:** не теряем оплаченные заказы;
* **Риск:** двойной запуск печати при повторах → **идемпотентность по orderId** на стороне PrintGateway.

## 2) Доступность

* **Сценарий:** недоступен Billing или Payments.
* **Механизмы:** circuit breaker + graceful degradation (можно сохранить **draft** заказа без оплаты); DLQ для событий.
* **Ожидаемо:** создание draft работает (99.95%), подтверждение ждёт восстановления провайдера; заказы не теряются.

## 3) Производительность

* **Сценарий:** пользователь получает котировку и подтверждает заказ.
* **Механизмы:** синхронный вызов Quote; все тяжёлые операции (печать, вебхуки) асинхронно.
* **Метрики:** `Create→Quote` ≤ **300 мс**; `Confirm` (инициация платежа) ≤ **500 мс**; UI получает статус в реальном времени по событиям.

## 4) Масштабируемость

* **Сценарий:** всплеск 10× (сессии экзаменов).
* **Механизмы:** горизонтальный скейл; Kafka/NATS для событий; PrintGateway шардируется по магазинам.
* **Метрики:** удерживаем ≥ **500 rps** на Create/Confirm при линейном скейле; 

## 5) Модифицируемость

* **Сценарий:** добавить новый параметр печати (например, скрепление/степлер) и новый тип устройства.
* **Механизмы:** декларативная модель параметров (schema/JSON) в Print Orders Service; **PrintGateway = набор адаптеров** (Adapter pattern).
* **Ожидаемо:** изменение без каскада по системе; TTM фичи ≤ **2 недели**; затрагиваются Print Orders Service DTO + один адаптер PG.

## 6) Безопасность

* **Сценарий:** злоумышленник пытается переиспользовать `assetUrl`.
* **Механизмы:** короткий TTL presigned, строгое соответствие `orderId↔docId` (Print Orders Service валидирует), PrintGateway скачивает по серверной сети (без утечки в интернет).
* **Метрики:** 0 успешных неавторизованных скачиваний; время ротации ключей PrintGateway ≤ **24 ч**.

## 7) Наблюдаемость/диагностика

* **Сценарий:** часть заказов «застряла» между Paid и Printing.
* **Механизмы:** сквозной traceId; бизнес-SLI: **time-to-first-page**, **pay→start**, **fail ratio**; алерты на превышение порогов.
* **Метрики:** MTTR (Mean Time To Repair / Restore / Recovery) инцидента ≤ **30 мин**; доля «застрявших» < **0.2%**; авто-ретраи с джиттером.
  
Основные бизнес-SLI в контексте печати

| Метрика                | Расшифровка / Что измеряет                                                          | Почему важна                                                                                     |
| ---------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **time-to-first-page** | Время от начала печати до выхода первой страницы из принтера                        | Показывает фактическую скорость и отзывчивость сервиса печати (влияет на клиентский UX).         |
| **pay→start**          | Время от момента успешной оплаты до начала печати                                   | Отражает, насколько быстро система передаёт задание на принтер (оперативность цепочки ORD → PG). |
| **fail ratio**         | Доля неудачных заказов (ошибки печати, отмены, сбои оплаты) от общего числа заказов | Измеряет надёжность и устойчивость бизнес-процесса.                                              |

---

# Сильные стороны решения

* Чёткое разделение ответственности: расчёт/оплата отделены от печати; тяжёлый контент идёт минуя Print Orders Service.
* Устойчивость к сбоям за счёт событийной модели, outbox и идемпотентности.
* Хорошая модифицируемость через адаптеры PrintGateway и схему параметров.

# Зоны риска и как смягчить

* **Зависимость от внешних провайдеров** (Payments/Billing)
* **Дублирование печати** при повторах: строгая идемпотентность в PrintGateway и блокировка по `orderId`.
* **Edge-безопасность presigned URL**: короткие TTL, скачивание только сервером PrintGateway, одноразовые ссылки.

--- 

### 2. Сервис **Payments** (платёжный фасад).

Что делает Payments

* Унифицированный **фасад** над внешними провайдерами (CloudPayments/YooMoney/UnitPay/…).
* Создание платежей/интентов, подтверждение, вебхуки, возвраты.
* Идемпотентность, биллинг-сигналы и события для downstream (PrintOrders, Billing, Notifications).
* Хранит минимальные метаданные и статусы, **не хранит** чувствительные PAN-данные (токены провайдера).

---

 Взаимодействие (критичный сценарий: «Инициация и подтверждение онлайн-платежа с вебхуком»)

```mermaid
sequenceDiagram
  autonumber
  participant UI as Web/Mobile UI
  participant APIGW as API Gateway
  participant ORD as PrintOrders
  participant PAY as Payments (Facade)
  participant PROV as Provider (Stripe/Adyen)
  participant BILL as Billing
  participant BUS as Event Bus

  Note over UI: Пользователь подтверждает оплату заказа
  UI->>APIGW: POST /print-orders/{id}/confirm {paymentMethod}
  APIGW->>ORD: Confirm(orderId)
  ORD->>PAY: CreatePayment {orderId, amount, currency, method, idempotencyKey}
  PAY->>PROV: Create PaymentIntent/Session (idempotencyKey)
  PROV-->>PAY: {providerPaymentId, clientSecret}
  PAY-->>ORD: {paymentId, clientSecret}
  ORD-->>APIGW: {clientSecret}
  APIGW-->>UI: Завершение оплаты через SDK/3DS

  Note over PROV,UI: Провайдер выполняет 3DS/банковскую аутентификацию
  PROV-->>PAY: (Webhook) payment.succeeded {providerPaymentId, amount, orderRef}
  PAY->>PAY: Verify signature, idempotency, update status=SUCCEEDED
  PAY-->>BUS: Payment.Succeeded {paymentId, orderId, amount}
  BUS-->>ORD: Route event
  ORD->>BILL: Capture/Record {orderId, amount}  %% если биллинг считает начисления
  ORD-->>UI: Заказ оплачен, переходим к печати
```

> Примечания:
>
> * Вызов `CreatePayment` синхронный; финальный статус приходит **через вебхук** (асинхронно).
> * Используется **idempotencyKey** и на стороне Payments, и на стороне провайдера.
> * Подписанный вебхук проверяется по секрету/сертификату, события — через Outbox.

---

# Оценка архитектурного решения (Quality Attribute Scenarios)

## 1) Надёжность / согласованность

* **Сценарий:** провайдер прислал дублирующий вебхук `payment.succeeded`.
* **Механизм:** идемпотентная обработка по `providerPaymentId` + состояние `processedAt`; транзакционный Outbox для `Payment.Succeeded`.
* **Отклик/Метрики:** 0 двойных публикаций; обработка вебхука ≤ **300 мс**.
* **Риски:** гонка между несколькими воркерами → решается блокировкой по ключу или `SELECT … FOR UPDATE`.

## 2) Доступность

* **Сценарий:** временная недоступность провайдера при `CreatePayment`.
* **Механизм:** circuit breaker, экспоненциальные ретраи с джиттером; возврат статуса `PENDING_PROVIDER`.
* **Отклик:** успешное создание платежа ≥ **99.9%** за 10 мин; UI показывает «подтверждение выполняется», Print Orders Service ждёт вебхук.
* **Риски:** длительная деградация → рост очереди; лимитируется rate-limit/TTL.

## 3) Производительность

* **Сценарий:** пользователь жмёт «Оплатить», нужен clientSecret за один RTT.
* **Механизм:** синхронный фасад к `Create PaymentIntent`.
* **Метрики:** `CreatePayment` ≤ **250 мс**; end-to-end (UI→clientSecret) ≤ **500 мс** (без 3DS времени банка).

## 4) Масштабируемость

* **Сценарий:** пик 10× по платежам (например, массовые заказы).
* **Механизм:** stateless API, воркеры вебхуков с автоскейлом, идемпотентность, шардирование по `providerPaymentId`.
* **Метрики:** устойчиво ≥ **300 rps** `CreatePayment`, ≥ **600 rps** вебхуков; DLQ < **0.1%**.

## 5) Модифицируемость

* **Сценарий:** добавить нового провайдера (локальный агрегатор).
* **Механизм:** слой `ProviderAdapter` (Adapter/Strategy), унифицированные доменные события, маппинг кодов ошибок.
* **Метрики:** TTM интеграции ≤ **2–3 недели**; изменения локализованы в одном адаптере + конфиг.

## 6) Безопасность и соответствие

* **Сценарий:** попытка подделать вебхук.
* **Механизм:** проверка подписи тела (секрет/сертификат), при несоответствии → 4xx без сайд-эффекта; IP-allowlist (если доступно).
* **Метрики:** 0 успешных неаутентичных вебхуков; MTTR ротации секрета ≤ **30 мин**.
* **PCI-DSS:** PAN не хранится; только токены провайдера и метаданные; шифрование PII, KMS; журнал аудита.

## 7) Наблюдаемость/диагностика

* **Сценарий:** заказы зависают в «оплата в процессе».
* **Механизм:** сквозной `traceId` из Print Orders Service в PAY и в провайдера (через metadata), метрики «age of pending».
* **Метрики:** MTTR ≤ **30 мин**; доля платежей в `PENDING` > **5 мин** < **0.5%**.

---

# Архитектурные решения (сильные стороны)

* **Фасад + адаптеры** → единый контракт для домена, лёгкая смена/добавление провайдера.
* **Идемпотентность сквозь весь путь** (idempotencyKey, providerPaymentId) → отсутствие дублей.
* **Событийная интеграция** c Print Orders Service/Billing (Outbox) → устойчивость к временному разрыву между оплатой и доменом.

# Зоны риска и смягчение

* **Несогласованность статусов** (провайдер «успех», но Print Orders Service не обновился): обязательный Outbox + ретраи публикаций; Print Orders Service подписывается и идемпотентно применяет.
* **Потеря вебхука**: повторные запросы провайдера + наш DLQ и периодический «reconcile» статусов по провайдеру.
