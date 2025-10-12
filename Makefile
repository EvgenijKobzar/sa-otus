# Папки
DSL_DIR=docs/architecture/dsl
MDD_DIR=docs/architecture/mermaid
DIAGRAMS_DIR=docs/architecture/diagrams

# CLI команды
STRUCTURIZR_DOCKER=docker run --rm -v $(PWD):/usr/local/structurizr structurizr/cli
PLANTUML_DOCKER=docker run --rm -v $(PWD):/data plantuml/plantuml
MERMAIND_DOCKER=docker run --rm -v $(PWD):/data minlag/mermaid-cli

# Цель по умолчанию
default: diagrams

# Генерация диаграмм через Docker
diagrams-docker:
$(STRUCTURIZR_DOCKER) export \
-workspace /usr/local/structurizr/$(DSL_DIR)/workspace.dsl \
-format plantuml \
-output /usr/local/structurizr/$(DIAGRAMS_DIR)

diagrams-docker-from-json:
$(STRUCTURIZR_DOCKER) export \
-workspace /usr/local/structurizr/$(DSL_DIR)/workspace.json \
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

# Модель предметной области
diagrams-mermaid-svg:
$(MERMAIND_DOCKER) \
-i $(MDD_DIR)/*.mmd

diagrams-mermaid-png:
$(MERMAIND_DOCKER) \
-i $(MDD_DIR)/*.mmd \
-o $(MDD_DIR)/*.png \
--scale 10

# Очистка сгенерированных файлов
clean:
rm -rf $(DIAGRAMS_DIR)/*