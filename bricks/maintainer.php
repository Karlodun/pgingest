<h1>Welcome <?php echo $_SESSION['maintainer'] ?></h1>
<div id="logout"><a href="logout.php">Logout</a></div>

<div style="background:#d2ffd6">
<?php echo "<script>console.log("; echo json_encode($_POST); echo ");</script>"?> <-- this should be disabled for prod, since it reveals sensitive data -->
</div>

<?php
$my_roles=$app_conn->query("select unnest(my_roles) from grimoire.my_roles;")->fetchAll(PDO::FETCH_COLUMN);
if (isset($_POST['current_role']))      {$_SESSION['current_role']=$_POST['current_role'];}
if (!isset($_SESSION['current_role']))  {$_SESSION['current_role']=$_SESSION['maintainer'];}

if (isset($_POST['active_roles']))      {$_SESSION['active_roles']=array_keys($_POST['active_roles']);}
if (!isset($_SESSION['active_roles']))  {$_SESSION['active_roles'][]=$_SESSION['current_role'];}

$app_conn->exec("set role=".$_SESSION['current_role']);
$current_roles=$app_conn->query("select unnest(my_roles) from grimoire.current_roles;")->fetchAll(PDO::FETCH_COLUMN);

$filter_maintainer=implode(array_intersect($_SESSION['active_roles'], $current_roles),"', '");
$import_sources=$app_conn->query("select * from grimoire.import_source where maintainer in ('$filter_maintainer');")->fetchAll(PDO::FETCH_ASSOC);

#if (!isset($_SESSION['current_source'])) {$_SESSION['current_source']='';}
if (isset($_POST['current_source']) && in_array($_POST['current_source'],array_column($import_sources,'import_name')))    {$_SESSION['current_source']=$_POST['current_source'];}

if(!empty($_FILES['uploaded_file'])){
    $tmp_file=$_FILES['uploaded_file']['tmp_name'];
    if ($import_name=$_SESSION['current_source'])   {
        $task_id=shell_exec("bin/import.sh $import_name $tmp_file 2>&1");
#        $task_id=shell_exec("zcat $tmp_file > tmp/raw_import_$import_name 2>/dev/null || cat $tmp_file > tmp/raw_import_$import_name; bin/import.sh $import_name tmp/raw_import_$import_name 2>&1");
    }
    $app_conn->exec("UPDATE grimoire.task_board SET maintainer='".$_SESSION['current_role']."' WHERE task_id=$task_id; ");
    echo "task id: $task_id";
}

echo "<pre>";
#print_r(array_column($import_sources,'import_name'));
#echo "in array: ".in_array( $_POST['current_source'], array_column($import_sources,'import_name') );
#echo "task id: $task_id";
echo "</pre>";
$bricks=[
    'task_board',
    'edit_source',
    'new_source',
    'schema_definition'
];
?>

<nav>

</nav>

<?php
require_once 'role_picker.php';
require_once 'active_roles.php';
require_once 'import_sources.php';
require_once 'my_tasks.php';
?>

<form id="upload_file" action="index.php" method="post" enctype="multipart/form-data">
    <fieldset><legend>Upload your file</legend>
        <input type="file" name="uploaded_file">
        <input type="submit" value="Upload File" name="submit">
    </fieldset>
</form>

