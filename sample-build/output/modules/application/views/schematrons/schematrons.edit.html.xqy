(:@GENERATED@:)
xquery version "1.0-ml";
declare default element namespace "http://www.w3.org/1999/xhtml";
import module namespace response = "http://www.xquerrail-framework.com/response" at "/_framework/response.xqy";
declare option xdmp:output "indent-untyped=yes";
declare variable $response as map:map external;
let $init := response:initialize($response)
return
<div xmlns="http://www.w3.org/1999/xhtml" id="form-wrapper">
   <div class="inner-page-title">
      <h2>Edit Schematrons</h2>
   </div>
   <div class="content-box">
      <form name="form_schematron" method="post" action="/schematrons/save.html">
         <ul class="editPanel">
            <li>
               <label class="desc" for="id">Schematron ID</label>
               <input id="d4e324" name="id" class="field text" value="{response:body()//*:id}"/>
            </li>
            <li>
               <label class="desc" for="name">Name</label>
               <input id="d4e331" name="name" class="field text" value="{response:body()//*:name}"/>
            </li>
            <li>
               <label class="desc" for="schematronElement">Schematron Element</label>
               <input id="d4e338" name="schematronElement" class="field text"
                      value="{response:body()//*:schematronElement}"/>
            </li>
            <li class="buttons">
               <label/>
               <button id="saveButton" class="ui-state-default ui-corner-all ui-button" type="submit">Save</button>
               <button id="cancelButton" class="ui-state-default ui-corner-all ui-button"
                       type="button">Cancel</button>
            </li>
         </ul>
      </form>
   </div>
   <div class="clearfix"/>
</div>