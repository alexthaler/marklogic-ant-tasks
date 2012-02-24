xquery version "1.0-ml";

module namespace config = "http://www.xquerrail-framework.com/config";

import module namespace response = "http://www.xquerrail-framework.com/response"
   at "/_framework/response.xqy";
import module namespace request  = "http://www.xquerrail-framework.com/request"
   at "/_framework/request.xqy";
   
declare namespace routing = "http://www.xquerrail-framework.com/routing";   
   

declare variable $CONFIG := xdmp:invoke("/_config/config.xml");
declare variable $ENGINE-PATH := "/_framework/engines";

(:Standard Error Messages:)
declare variable $ERROR-RESOURCE-CONFIGURATION := xs:QName("ERROR-RESOURCE-CONFIGURATION");

(:~
 : Returns the default controller for entire server usually default
:)
declare function config:default-controller()
{
  fn:string($CONFIG/config:default-controller/@resource)
};
declare function config:resource-directory() as xs:string
{
   if(fn:not($CONFIG/config:resource-directory))
   then "/resources/"
   else fn:data($CONFIG/config:resource-directory/@resource)
};
(:~
 : Returns the default action 
:)
declare function config:default-action()
{
  fn:string($CONFIG/config:default-action/@value)
};

(:~
 : Returns the default format
:)
declare function config:default-format()
{
  fn:string($CONFIG/config:default-format/@value)
};

declare function config:get-front-controller()
{
  fn:string($CONFIG/config:front-controller/@resource)
};

declare function config:get-application($name as xs:string)
{
   $CONFIG/config:application[@name eq $name]
};

(:~
 : Get the current application directory
 :)
declare function config:application-directory($name)
{
   fn:concat(config:get-application($name)/@uri)
};


(:~
 : Returns the routes configuration file 
:)
declare function config:get-routes()
{
  xdmp:invoke($CONFIG/config:routes/@resource) 
};

(:~
 : Returns the engine for processing requests satisfying the request
~:)
declare function config:get-engine($response as map:map)
{
   let $_ := response:set-response($response)
   return
     if(response:format() eq "html") 
     then "engine.html"
     else if(response:format() eq "xml")
     then "engine.xml"
     else if(response:format() eq "json")
     then "engine.json"
     else fn:string($CONFIG/config:default-engine/@value)
};
