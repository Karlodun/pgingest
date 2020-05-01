<form id="import_sources" action="index.php" method="POST">
    <fieldset class="picklist">
        <legend>import sources</legend>
        <div class='tr th'>
        <span class='source_import_name'>import name</span>
        <span class='source_maintainer'>maintainer</span>
        <span class='source_last_update'>last update</span>
        </div>
        <?php foreach ($import_sources as $source){
            $on=($source['import_name']==$_SESSION['current_source']) ? "checked" : "";
            echo "
            <div class='tr'>
            <input type='radio' name='current_source' value='".$source['import_name']."' id='cs_".$source['import_name']."' class='vt' $on onchange='this.form.submit()'>
            <label for='cs_".$source['import_name']."'>
                <span class='source_import_name'>".$source['import_name']."</span>
                <span class='source_maintainer'>".$source['maintainer']."</span>
                <span class='source_last_update'>".$source['last_update']."</span>
            </label>
            </div>
            ";
            }
        ?>
        <!--input type="submit" value="apply"-->
    </fieldset>
</form>

<form id="import_source_config" action="index.php" method="POST">
    <fieldset>
        <legend>import source config</legend>
        <!--input type="submit" value="apply"-->
    </fieldset>
</form>

