# 4. Использование Structurizr CLI для генерации диаграмм из DSL

Дата: 2025-09-24

## Статус
Принято

## Контекст
Мы описываем архитектуру с помощью **Structurizr DSL**.  
Для удобства команды и внешних стейкхолдеров необходимо генерировать визуальные диаграммы (PlantUML, PNG, SVG и др.).  
Возможные варианты:
- Рисовать диаграммы вручную (draw.io, diagrams.net) — не воспроизводимо и тяжело поддерживать в актуальном состоянии;
- Использовать Structurizr Lite (веб-приложение) — требует поднятия сервиса и не всегда удобно для CI/CD;
- Использовать **Structurizr CLI**, который работает с DSL локально и в CI/CD, поддерживает экспорт в PlantUML, Mermaid, DOT и другие форматы.

## Решение
Мы будем использовать **Structurizr CLI**:
- DSL хранится в `docs/architecture/dsl/`;
- Диаграммы генерируются CLI-командой:
  ```bash
  structurizr export \
    -workspace docs/architecture/dsl/workspace.dsl \
    -format plantuml \
    -output docs/architecture/diagrams
  ``` 
- Для удобства использования в CI/CD и локально без установки Java/CLI будет применяться Docker-образ
  ```bash
  docker run --rm -v $(pwd):/usr/local/structurizr structurizr/cli \
    export -workspace /usr/local/structurizr/docs/architecture/dsl/workspace.dsl \
           -format plantuml \
           -output /usr/local/structurizr/docs/architecture/diagrams
  
  ```
- Дополнительно для CI/CD будет использоваться автоматическая конвертация PlantUML → PNG/SVG. 

## Последствия
- Все диаграммы воспроизводимы и могут быть обновлены автоматически;
- Уменьшается риск расхождения между моделью (DSL) и картинками (PNG/SVG);
- Разработчикам нужно иметь установленный Java и Structurizr CLI, либо использовать контейнер/CI для генерации.
- Для простоты вызова команды описаны в MakeFile