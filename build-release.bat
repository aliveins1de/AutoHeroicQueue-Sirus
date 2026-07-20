@echo off
REM Собирает AutoHeroicQueue.zip с правильной структурой папки
REM для загрузки на страницу релиза GitHub вручную.

echo Очищаю старую сборку...
if exist build rmdir /s /q build
if exist AutoHeroicQueue.zip del AutoHeroicQueue.zip

echo Собираю папку аддона...
mkdir build\AutoHeroicQueue
copy AutoHeroicQueue.toc build\AutoHeroicQueue\ >nul
copy AutoHeroicQueue.lua build\AutoHeroicQueue\ >nul

echo Упаковываю в zip...
cd build
tar -a -c -f ..\AutoHeroicQueue.zip AutoHeroicQueue
cd ..

echo.
echo Готово: AutoHeroicQueue.zip лежит в текущей папке.
pause
