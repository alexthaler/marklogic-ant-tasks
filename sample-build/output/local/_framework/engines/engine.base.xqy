xquery version "1.0-ml";
(:~
 : Performs core engine for transformation and base implementation for 
 : different format engines
~:)
module namespace engine = "http://www.xquerrail-framework.com/engine";

import module namespace request = "http://www.xquerrail-framework.com/request"
   at "/_framework/request.xqy";
import module namespace response = "http://www.xquerrail-framework.com/response"
   at "/_framework/response.xqy";
import module namespace config = "http://www.xquerrail-framework.com/config"
   at "/_framework/config.xqy";
   
declare namespace tag = "http://www.xquerrail-framework.com/tag";    

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";


declare variable $engine-transformer as xdmp:function? := xdmp:function(xs:QName("engine:transformer"));
declare variable $visitor := map:map();
declare variable $_child-engine-tags := map:map();
declare variable $_helpers := map:map();

(:~
 : The for iterator requires a global stack
:)
declare variable $_for_vars := map:map();

(:~
 : To allow your engine to route transform calls from base
 : You must register your engines transformer function in
 : order for the base engine to route any functions you will handle
~:)
declare function engine:set-engine-transformer($func as xdmp:function)
{
   xdmp:set($engine-transformer,$func)
};
(:~
 : Register any custom tags you will be overriding from custom engine
~:)
declare function engine:register-tags($tagnames as xs:QName*)
{
  for $tag in $tagnames
  return
    map:put($_child-engine-tags,fn:string($tag),$tag)
};
(:~
 : Check to see if a tag has been registered with the engine
~:)
declare function engine:tag-is-registered(
  $tag as xs:string
)
{
  if(fn:exists(map:get($_child-engine-tags,fn:string($tag)))) 
  then fn:true()
  else fn:false()
};

(:~
 : Marks that a node has been visited during transformation
 : When building custom tag that requires a closing tag 
 : ensure that you consume the results you process or you
 : will find duplicate or spurious output results 
~:)
declare function engine:consume($node)
{
  (
     map:put($visitor,fn:generate-id($node),"x")
  )
};
(:
: Marks that a node has been visited and returns that node
:)
declare function engine:visit($node)
{
  (
     map:put($visitor,fn:generate-id($node),"x"),$node
  )
};
(:~
 :  Returns boolean value of whether a node has been visited.
~:)
declare function engine:visited($node)
{
    fn:exists(map:get($visitor,fn:generate-id($node)))
};

(:~
 : Transforms an if tag for processing
~:)
declare function engine:transform-if($node as node())
{
  let $endif := $node/following-sibling::processing-instruction("endif")[1]
  let $else  := $node/following-sibling::processing-instruction("else")[1]
  let $overlap := $node/following-sibling::processing-instruction("if")[. << $endif]
  let $_ := 
     if($overlap) 
     then fn:error(xs:QName("TAG-ERROR"),"Overlapping if tags")
     else ()  
  let $ifvalue := 
        if($else) then (
            $node/following-sibling::node()[. << $else]
        )
        else (
            xdmp:log(("IF Condition:",$node/following-sibling::node()[. << $endif])),
            $node/following-sibling::node()[. << $endif]
        )
  let $elsevalue := 
        if($else) then $else/following-sibling::node()[. << $endif]
        else ()
  let $condition := xdmp:value(fn:concat("if(", fn:data($node), ") then fn:true() else fn:false()"))
  return
    (
    engine:consume($endif),
    engine:consume($else),
    if($condition  eq fn:true()) 
    then (
          for $n in $ifvalue return engine:transform($n),
          for $n in $elsevalue return engine:consume($n),
          for $n in $ifvalue return engine:consume($n)
         )
    else ( 
           for $n in $elsevalue return engine:transform($n),
           for $n in $ifvalue return engine:consume($n),
           for $n in $elsevalue return engine:consume($n)
         )
    )
};
(:~
 : The for tag must handle its one process 
   and return the context to the user
~:)
declare function engine:process-for-this(
   $this-tag as processing-instruction("this"),
   $this)
{
  let $this-value := fn:string($this-tag)
  return
     (engine:consume($this-tag),
      for $v in xdmp:value($this-value) 
      return 
        typeswitch($v)
          case element() return engine:transform($v)
          case attribute() return fn:data($v)
          default return $v
     ) 
};
(:~
 : The for tag must handle its one process 
   and return the context to the user
~:)
declare function engine:process-for-context($nodes,$context)
{
   for $node in $nodes
   return
     typeswitch($node)
     case element() return
            if($node//processing-instruction("this"))
            then element {fn:node-name($node)}
            {
              $node/@*,
              engine:process-for-context($node/node(),$context)
            }
            else $node
      case processing-instruction("this") return engine:process-for-this($node,$context)   
      default return $node  
};
(:~
   Syntax :
    <?for $data//search-result ?>
       <div>
          <?fragment name="" location="" ?>
          <h2 class="title"><?this $this/title?></h2>
          <div><?this fn:string($this/@uri)?> </div>
          <div class="snippet">
            <?this $this/snippet/*?> 
          </div>
       </div>
    <?else?>
    <div>No Search Results Found...</div>
    <?endfor?>
:)
declare function engine:transform-for(
   $for-tag as processing-instruction("for")
)
{
    let $endfor-tag := $for-tag/following-sibling::processing-instruction("endfor")
    let $elsefor-tag := $for-tag/following-sibling::processing-instruction("elsefor")
    let $overlap := $for-tag/following-sibling::processing-instruction("for")[. << $for-tag]
    (:Validate Conditions here:)
    let $_ := 
       (  
         if($overlap) 
         then fn:error(xs:QName("TAG-ERROR"),"Overlapping <?for?> tags")
         else (),
         if($endfor-tag) 
         then () 
         else fn:error(xs:QName("TAG-ERROR"),"Missing <?endfor?> tag")
       )   
     
    (:Now Worry about the values:)   
    let $for-process := fn:data($for-tag)
    let $for-values := xdmp:value($for-process)
    let $for-data := 
        if($elsefor-tag) 
        then $for-tag/following-sibling::node()[. << $elsefor-tag] 
        else $for-tag/following-sibling::node()[. << $endfor-tag]
    let $elsefor-data := 
        if($elsefor-tag) 
        then $elsefor-tag/following-sibling::node()[. << $endfor-tag] 
        else ()
    return
     (
        engine:consume($for-tag),
        engine:consume($endfor-tag),
        engine:consume($elsefor-tag),
        if(fn:exists($for-values)) then
        (
           for $d in $elsefor-data return engine:consume($d),
           for $v in $for-values return engine:process-for-context($for-data,$v),
           for $d in $for-data return engine:consume($d)
        )  
        else
        (
           for $d in $elsefor-data return engine:transform($d),
           for $d in $for-data return engine:consume($d),
           for $d in $elsefor-data return engine:consume($d)
        )            
     )
};

declare function engine:transform-has_slot($node as node())
{
  let $end_tag := $node/following-sibling::processing-instruction("end_has_slot")
  let $content := $node/following-sibling::*[. << $end_tag]
  let $tag_data := xdmp:unquote(fn:concat("<has_slot ",fn:data($node)," />"))/*
  let $slot := fn:string($tag_data/@slot) 
  return 
  (
    engine:consume($end_tag),
    if(response:has-slot($slot)) 
    then (
          for $n in $content return engine:transform($n),
          for $n in $content return engine:consume($n)
         )
    else ( 
          for $n in $content return engine:consume($n)
         )  
  ) 
};

declare function engine:transform-slot($node as node())
{
  let $tag_data := xdmp:unquote(fn:concat("<slot ",fn:data($node)," />"))/*
  let $slot := $tag_data/@slot
  let $endslot := $node/following-sibling::processing-instruction("endslot")[1]
  let $is_closed := if($endslot) then () else fn:error(xs:QName("MISSING-END-TAG"),"slot tag is missing end tag <?endslot?>")
  let $slotcontent := $node/following-sibling::*[. << $endslot]
  let $setslot := response:slot($slot)
  let $log := xdmp:log(("slot:",$setslot))
  return
  (  engine:consume($endslot),
     if(fn:exists($setslot)) 
     then for $n in $setslot return (engine:transform($n), engine:consume($n))
     else for $n in $slotcontent return (engine:transform($n), engine:consume($n))
  )  
};
declare function engine:template-uri($name)
{
  fn:concat(config:application-directory(response:application()),"/templates/",$name,".html.xqy")
};

declare function engine:view-uri($controller,$action)
{
  fn:concat(config:application-directory(response:application()),"/views/",$controller,"/",$controller,".",$action,".html.xqy")
};

declare function engine:render-template($response)
{
    let $template-uri := 
        fn:concat(
            config:application-directory(response:application()),
            "/templates/",
            response:template(),
            ".html.xqy")
    for $n in xdmp:invoke($template-uri,(
            xs:QName("response"),$response
        ))
    return 
      engine:transform($n)
};
(:~
 : Partial rendering intercepts a call and routes only the view, even if a template is defined.
 : This is to support ajax type calls for rendering views in a frame or container
~:)
declare function engine:render-partial($response)
{
   engine:render-view()
};

declare function engine:render-view()
{
    let $view-uri := engine:view-uri(response:controller(),response:view())
    for $n in xdmp:invoke($view-uri,(
            fn:QName("","response"),response:response()
        ))
    return 
      engine:transform($n)
};

declare function engine:transform-template($node)
{
   let $dummy := xdmp:unquote(fn:concat("<template ",fn:data($node),"/>"))/*
   for $n in xdmp:invoke(engine:template-uri($dummy/@name),
     (
        fn:QName("","response"),response:response() 
     )
     ) 
     return engine:transform($n)
};

declare function engine:transform-view($node)
{
   let $dummy := xdmp:unquote(fn:concat("<view ",fn:data($node),"/>"))/*
   let $view  := response:view()
   let $controller := response:controller()
   return
     for $n in xdmp:invoke(engine:view-uri($controller,$view),
     (
        fn:QName("","response"),response:response()
     )
     )  
     return engine:transform($n)
};

declare function engine:transform-dynamic($node as node())
{
  let $engine-tag-qname := fn:concat("engine:",fn:local-name($node))
  let $is-registered := engine:tag-is-registered($engine-tag-qname)
  return 
        if($is-registered) 
        then xdmp:apply($engine-transformer,$node)
        else 
          let $name := fn:local-name($node)
          let $func-name := xs:QName(fn:concat("tag:apply"))
          let $func-uri  := fn:concat("/application/tags/",$name,"-tag.xqy")
          let $func := xdmp:function($func-name,$func-uri)
          return
            try{
             xdmp:apply($func,$node,response:response())
            } catch($ex)
            {
              "",
              xdmp:log($ex)
            }
};
(:
  Core processing-instructions and any other data should be handled here
:)
declare function engine:transform($node as item())
{  
   if(engine:visited($node))
   then  ()    
   else(
       typeswitch($node)
         case processing-instruction("template") return engine:transform-template($node)
         case processing-instruction("view") return engine:transform-view($node) 
         case processing-instruction("if") return engine:transform-if($node)
         case processing-instruction("for") return engine:transform-for($node)
         case processing-instruction("has-slot") return engine:transform-has_slot($node)
         case processing-instruction("slot") return engine:transform-slot($node)
         case processing-instruction() return engine:transform-dynamic($node)
         case element() return
          if(fn:not($node//processing-instruction()))
          then $node
          else
           element {fn:node-name($node)}
           {
             $node/@*,
             for $n in $node/node()
             return engine:transform($n)
           }
         case text() return $node
         default return $node
     )    
};