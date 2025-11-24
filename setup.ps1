# Script de configuration initiale pour SYCEBNL Accounting
# Exécuter avec : .\setup.ps1

Write-Host "🚀 Configuration de SYCEBNL Accounting..." -ForegroundColor Cyan
Write-Host ""

# 1. Vérifier Flutter
Write-Host "📦 Vérification de Flutter..." -ForegroundColor Yellow
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "✅ Flutter trouvé" -ForegroundColor Green
    flutter --version
}
else {
    Write-Host "❌ Flutter non trouvé. Installez Flutter depuis https://flutter.dev" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 2. Créer le fichier .env s'il n'existe pas
if (-not (Test-Path ".env")) {
    Write-Host "📝 Création du fichier .env..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "✅ Fichier .env créé" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️  IMPORTANT : Éditez le fichier .env et ajoutez vos clés Supabase !" -ForegroundColor Yellow
    Write-Host "   SUPABASE_URL=https://votre-projet.supabase.co" -ForegroundColor White
    Write-Host "   SUPABASE_ANON_KEY=votre_cle_anonyme" -ForegroundColor White
    Write-Host ""
    
    # Demander si on doit ouvrir le fichier
    $response = Read-Host "Voulez-vous ouvrir .env maintenant ? (O/N)"
    if ($response -eq "O" -or $response -eq "o") {
        notepad .env
    }
}
else {
    Write-Host "✅ Fichier .env existe déjà" -ForegroundColor Green
}

Write-Host ""

# 3. Installer les dépendances
Write-Host "📦 Installation des dépendances Flutter..." -ForegroundColor Yellow
flutter pub get

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Dépendances installées" -ForegroundColor Green
}
else {
    Write-Host "❌ Erreur lors de l'installation des dépendances" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 4. Vérifier la configuration Flutter
Write-Host "🔍 Vérification de la configuration Flutter..." -ForegroundColor Yellow
flutter doctor

Write-Host ""
Write-Host "✅ Configuration terminée !" -ForegroundColor Green
Write-Host ""
Write-Host "📚 Prochaines étapes :" -ForegroundColor Cyan
Write-Host "   1. Assurez-vous d'avoir rempli le fichier .env avec vos clés Supabase" -ForegroundColor White
Write-Host "   2. Exécutez les migrations SQL dans votre projet Supabase" -ForegroundColor White
Write-Host "   3. Lancez l'application avec : flutter run" -ForegroundColor White
Write-Host ""
Write-Host "📖 Pour plus d'informations, consultez GETTING_STARTED.md" -ForegroundColor Cyan
