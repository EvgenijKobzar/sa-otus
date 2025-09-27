model {

	client = person "Клиент" "Пользователь, создающий/редактирующий документы и заказывающий печать через веб-интерфейс."{
		tags "Не доверенная зона"
		tags "Initiator"
	}
	storeStaff = person "Сотрудник магазина" "Обрабатывает локальные заказы печати и взаимодействует с POS/принт-системой."{
		tags "Частично доверенная зона"
		tags "Initiator"
	}
	manager = person "Менеджмент сети" "Отслеживает бизнес-метрики, управляет тарифами и политиками."{
		tags "Частично доверенная зона"
		tags "Initiator"
	}

	group "Не доверенная зона" {
		paymentGateway = softwareSystem "Платёжный шлюз" "Сторонний провайдер онлайн-платежей (карты, кошельки, подписки)."{
			tags "Не доверенная зона"
			tags "Initiator"
			tags "External"
		}
		webBrowser = softwareSystem "Веб-браузер" "Клиентский интерфейс (браузерное приложение)."{
			tags "Не доверенная зона"
			tag "External"
			tags "External"
		}
	}
	group "Доверенная зона" {
		platform = softwareSystem "Print & Docs Platform" "Онлайн-платформа «всё-в-одном» для создания, редактирования, хранения, версионирования и заказа печати документов."{
			tags "Доверенная зона"
		}
		inStorePrintSystem = softwareSystem "Локальная система печати (в магазинах)" "Система POS/принтеров в филиалах, принимающая задания на печать. Ответственность: локальная буферизация/доставка задания на устройство, обработка драйвера."{
			tags "Доверенная зона"
		}
		notificationService = softwareSystem "Сервис уведомлений" "Email / SMS / Push-провайдер для уведомлений о статусе заказов."{
			tags "Доверенная зона"
			tags "Initiator"
		}
	}
	group "Частично доверенная зона" {
		cloudStorage = softwareSystem "Облачное хранилище" "Хранилище для документов, версий и резервных копий (S3-совместимое)."{
			tags "Частично доверенная зона"
			tag "External"
		}
		authProvider = softwareSystem "Сервис аутентификации" "OAuth / SSO провайдер (опционально)."{
			tags "Частично доверенная зона"
			tags "Initiator"
			tags "External"
		}
		legacyOps = softwareSystem "Сторонняя система операций" "Историческая система обработки операций, с которой ещё продолжается интеграция / миграция. Ответственность: бизнес-валидация, создание метаданных. Контракт интеграции: REST API (OpenAPI) — POST /api/print-jobs, GET /api/print-jobs/{id}; аутентификация: OAuth 2.0." {
			tags "Частично доверенная зона"
			tag "External"
			tags "External"
		}
	}

	// Взаимодействия (описания + протоколы)
	client -> platform "Использует для создания, редактирования, хранения и заказа печати" "HTTPS / REST / WebSockets (SPA)"
	storeStaff -> platform "Просматривает и обрабатывает входящие заказы печати" "HTTPS / REST / POS API"
	manager -> platform "Просматривает отчёты, управляет тарифами и шаблонами" "HTTPS / REST"

	platform -> webBrowser "Отдаёт UI / редактор" "HTML, JS" "HTTPS, JSON"

	platform -> paymentGateway "Инициирует платежи, проверяет статус транзакций" "REST/HTTPS, JSON"
	paymentGateway -> platform "Отправляет уведомления о статусе транзакций" "REST/HTTPS, Webhook"

	platform -> legacyOps "Синхронизирует операции / отправляет задания (временно)" "REST / JSON, очередь сообщений (RabbitMQ/Kafka)"

	platform -> inStorePrintSystem "Отправляет задания на печать, планирование и статусы готовности" "REST / MQ / SFTP"
	inStorePrintSystem -> platform "Возвращает статусы печати" "REST / MQ"

	platform -> cloudStorage "Сохраняет документы, версии и бэкапы" "S3 API / HTTPS"

	platform -> notificationService "Отправляет уведомления о статусе заказа/готовности" "HTTP API / SMTP / SMS API / Push API"
	notificationService -> client "Доставляет уведомления (SMS, email, push)" "SMTP, SMS, Push"

	platform -> authProvider "Аутентификация пользователей / управление правами" "OAuth2 / OpenID Connect / HTTPS"
	authProvider -> platform "Возвращает токены/атрибуты" "OAuth2 / OIDC / JWT"

}