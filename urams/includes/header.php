<?php
// includes/header.php
// Step: Common HTML head. Sob page same CSS/JS/font use korbe.
if (!isset($pageTitle)) { $pageTitle = 'URAMS'; }
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><?= e($pageTitle) ?></title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&family=Instrument+Serif:ital@0;1&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
  <link rel="stylesheet" href="public/assets/css/style.css">
</head>
<body>
<!-- Step: Dark mode button is common for all pages. -->
<button id="dm-toggle" title="Toggle Dark/Light Mode" onclick="toggleDarkMode()">
  <i class="fas fa-moon" id="dm-icon"></i>
</button>
<div id="toast-container"></div>
<div class="sidebar-overlay" id="sidebar-overlay" onclick="closeSidebar()"></div>