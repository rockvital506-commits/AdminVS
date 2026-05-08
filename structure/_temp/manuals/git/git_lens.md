



26_05_08
=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================


[PHASE 0] 🔍 Анализ: тип=learn,explain/3.5/5 / 2 домена (VSCode Ext + Git UX) / подзадачи: 1) Установка в WSL2-контексте → 2) Разбор UI-зон → 3) Маппинг команд/горячих клавиш → 4) Тюнинг под 16GB RAM → 5) Интеграция в daily workflow / логика: Diátaxis для снижения когнитивного нагрузки новичка / метрики: корректная работа в Remote-WSL, отключение тяжелого рендера, точный blame-анализ без ложных срабатываний

[MAIN] Техническое решение (Handoff Contract: `scope=VSCode+WSL2+Py3.13`, `success=настроенный UI+быстрый поиск истории+без лагов`)

### 1. 📘 Руководство (Guide): Принцип работы и установка
GitLens — визуальный слой над Git CLI. Транслирует `git blame`, `git log`, `git diff` в inline-аннотации, графы и панели VSCode. Работает локально, не требует сервера.
**Установка под WSL2 (критично для производительности):**
1. Откройте проект через `Remote - WSL` (`Ctrl+Shift+P` → `WSL: Connect to WSL`).
2. Extensions (`Ctrl+Shift+X`) → поиск `GitLens` → `Install in WSL: <distro>`.
3. `Developer: Reload Window`. GitLens автоматически подхватит Linux-бинд `git`, минуя Win-bridge (`wsl.exe`), что даёт `~2-3x` ускорение.

**Ключевые зоны интерфейса:**
- `Gutter` (левое поле номеров строк): автор/время последнего изменения.
- `Hover` (наведение): детальный diff строки + ссылка на коммит/PR.
- `CodeLens` (над функциями/классами): мета-данные о коммитах.
- `Sidebar (GitLens View)`: вкладки `Commits`, `Branches`, `File History`, `Repositories`.

### 2. 📋 Шпаргалка (Cheat Sheet): Команды и клавиши
| Задача | VSCode Command Palette | Default Hotkey | Результат |
|--------|------------------------|----------------|-----------|
| История текущей строки | `GitLens: Show Line History` | — | Timeline + blame + diff |
| Blame всего файла | `GitLens: Show File Blame` | `Alt+G B` | Виджет с навигацией по авторам |
| Сравнить файл с `HEAD` | `GitLens: Compare with HEAD` | ПКМ в SCM → `Compare` | Side-by-side diff |
| Поиск коммита по сообщению/автору | `GitLens: Show Commit Search` | `Alt+G S` | Фильтр с превью изменений |
| Быстрое скрытие gutter | `GitLens: Toggle Gutter Blame` | Клик по иконке `Blame` в статус-баре | UI очищается мгновенно |

### 3. 📖 Мануал (Reference): Настройки и архитектура
Управление через `settings.json` (`Ctrl+Shift+P` → `Open Settings (JSON)`).
**Оптимальный конфиг для 16GB RAM + WSL2:**
```json
{
  "gitlens.currentLine.enabled": true,
  "gitlens.currentLine.scrollable": false,
  "gitlens.hovers.enabled": true,
  "gitlens.codeLens.enabled": false,
  "gitlens.heatmaps.enabled": false,
  "gitlens.views.fileHistory.enabled": true,
  "gitlens.advanced.repositorySearchDepth": 1,
  "gitlens.gitCommands.closeOnFocusOut": true
}
```
**Архитектура под капотом:**
- Использует `git blame --porcelain` + `git log --format=...`.
- Кеширует метаданные в LRU-кеше расширения (~50MB RAM при активных файлах).
- В WSL2 запускает вызовы напрямую в Linux-окружении, избегая накладных расходов `9P` filesystem при маппинге `\\wsl$\`.
- Интегрируется с `vscode.git`, но не блокирует его. Работает асинхронно.

### 4. 🛡️ Рекомендации и ловушки (Best Practices + Stack)
• **Производительность:** `codeLens` и `heatmaps` сканируют AST и генерируют сотни декораций. Отключены по умолчанию для файлов >1500 строк. Включайте только для аудита критичных модулей.
• **Docker + WSL2:** Если `.git` примонтирован в контейнер, GitLens может зависать на `blame`. Открывайте проект строго через `Remote - WSL`, используйте `.dockerignore` для `.git/`.
• **Python 3.13 специфика:** `git blame` часто "ложно" фиксирует форматтеры (`black`, `ruff`). Используйте `GitLens: Show Quick File History` + включите `--ignore-revs-file .git-blame-ignore-revs` для игнора коммитов с `style: auto-format`.
• **Ловушка "False Context":** Blame показывает, кто тронул строку **последним**, а не кто написал логику. Для глубокого анализа используйте `git log -L` (GitLens поддерживает через `Show Line History`).
• **Workflow:** Держите `Gutter Blame` включённым только при ревью/дебаге. При написании кода отключайте через статус-бар, чтобы не отвлекаться на чужие изменения.



[RECOMMEND]
1. Создайте файл `.git-blame-ignore-revs` с хешами коммитов форматирования и настройте `git config blame.ignoreRevsFile .git-blame-ignore-revs`.
2. Добавьте `keybindings.json`: `{ "key": "alt+h", "command": "gitlens.showQuickFileHistory" }` для быстрого аудита.
3. Для визуализации DAG-веток используйте расширение `Git Graph` параллельно, если GitLens-вью не хватает.

[ANTICIPATE]
• Как настроить совместный просмотр blame с комментариями Pull Request прямо в редакторе?
• Почему в WSL2 GitLens иногда показывает `Unknown` автора и как фиксить GPG/SSH-контекст?
• Можно ли экспортировать историю изменений конкретного файла из GitLens в markdown для отчёта?