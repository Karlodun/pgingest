<form id="active_roles" action="index.php" method="POST">
    <fieldset>
        <legend>use roles</legend>
        <?php foreach ($current_roles as $role){
            $on=( in_array($role, array_intersect($_SESSION['active_roles'], $current_roles) )) ? "checked" : "";
            echo "<input type='checkbox' name='active_roles[$role]' id='ar_$role' $on><label for='ar_$role'>$role</label>";
            }
        ?>
        <input type="submit" value="apply">
    </fieldset>
</form>