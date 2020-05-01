<!DOCTYPE html>
<html lang="en">
<head>
    <title>CBRE Importer</title>
    <link rel="stylesheet" href="css/main.css">
    <link rel="stylesheet" href="css/lables.css">
    <link rel="stylesheet" href="css/import_sources.css">
    <link rel="stylesheet" href="css/my_tasks.css">
    <!--link rel="stylesheet" href="css/main.css"-->
    <!--script src="js/vue.js"></script-->
    <script>console.log(<?php json_encode($_POST);?>)</script>
    <style>

    </style>
</head>
<body>

<?php
session_start();
if (isset($_POST['pg_role'], $_POST['pg_pwd'])) {
    $_SESSION['maintainer']=$_POST['pg_role'];
        $_SESSION['app_dsn']="pgsql:host=de-microapps.csg2po3twyai.eu-west-2.rds.amazonaws.com;port=5432;dbname=cbre_importer" # host should be outsourced into config
        .";user=".$_POST['pg_role'].";password=".$_POST['pg_pwd'];
}

if (isset($_SESSION['app_dsn'])) { try{ $app_conn = new PDO($_SESSION['app_dsn']);}catch (PDOException $e){echo $e->getMessage();} }
if (!isset($app_conn)) {require_once 'bricks/login.php'; exit;}
require_once 'bricks/maintainer.php';
?>

</body>
</html>