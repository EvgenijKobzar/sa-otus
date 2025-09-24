# Папки
DSL_DIR=docs/architecture/dsl
DIAGRAMS_DIR=docs/architecture/diagrams

# CLI команды
STRUCTURIZR_DOCKER=docker run --rm -v $(PWD):/usr/local/structurizr structurizr/cli
PLANTUML_DOCKER=docker run --rm -v $(PWD):/data plantuml/plantuml

# Цель по умолчанию
default: diagrams

# Генерация диаграмм через Docker
diagrams-docker:
	$(STRUCTURIZR_DOCKER) export \
		-workspace /usr/local/structurizr/$(DSL_DIR)/workspace.dsl \
		-format plantuml \
		-output /usr/local/structurizr/$(DIAGRAMS_DIR)

# Конвертация .puml → PNG
png:
	$(PLANTUML_DOCKER) -tpng $(DIAGRAMS_DIR)/*.puml

# Конвертация .puml → SVG
svg:
	$(PLANTUML_DOCKER) -tsvg $(DIAGRAMS_DIR)/*.puml

# Генерация диаграмм (по умолчанию docker + PNG)
diagrams: diagrams-docker png

# Очистка сгенерированных файлов
clean:
	rm -rf $(DIAGRAMS_DIR)/*