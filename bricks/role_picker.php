<form id="role_picker" action="index.php" method="POST">
<fieldset>
<legend>current role:</legend>
    <select name='current_role' id='current_role' onchange='this.form.submit()'>
        <?php foreach ($my_roles as $role){
            $on=($role==$_SESSION['current_role']) ? "selected" : "";
            echo "<option value='$role' $on>$role</option>";
            }
        ?>
    </select>
</fieldset>
</form>