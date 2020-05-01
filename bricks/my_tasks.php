<?php 
$my_tasks=$app_conn->query("select * from grimoire.task_board where maintainer in ('$filter_maintainer') and import_name='".$_SESSION['current_source']."' ORDER BY task_id DESC;")->fetchAll(PDO::FETCH_ASSOC);
#echo "select * from grimoire.task_board where maintainer in ('$filter_maintainer') and import_name='".$_SESSION['current_source']."' ORDER BY task_id DESC;";
if (isset($_POST['task_id']))      {$_SESSION['current_task_id']=$_POST['task_id'];}
if (!isset($_SESSION['current_task_id']))  {$_SESSION['current_task_id']=0;}
?>

<form id="my_tasks" action="index.php" method="POST">
    <fieldset class="picklist">
        <legend>my tasks</legend>
        <div class='tr th'>
        <!--span class='task_import_name'>import name</span-->
        <span class='task_maintainer'>maintainer</span>
        <span class='task_start_time'>start time</span>
        <span class='task_status'>status</span>
        </div>
        <?php foreach ($my_tasks as $task){
            $on=($task['task_id']==$_SESSION['current_task_id']) ? "checked" : "";
            echo "
            <div class='tr'>
            <input type='radio' name='task_id' value='".$task['task_id']."' id='task_".$task['task_id']."' class='vt' $on onchange='this.form.submit()'>
            <label for='task_".$task['task_id']."'>
                <!--span class='task_import_name'>".$task['import_name']."</span-->
                <span class='task_maintainer'>".$task['maintainer']."</span>
                <span class='task_start_time'>".date_format(date_create($task['start_time']), "Y/m/d H:i")."</span>
                <span class='task_status'>".$task['status']."</span>
                </label>
            </div>
            ";
            }
        ?>
        <!--input type="submit" value="apply"-->
    </fieldset>
</form>
