/* This compressed file is part of Xinha. For uncomressed sources, forum, and bug reports, go to xinha.org */
function SaveSubmit(c){this.editor=c;this.changed=false;var b=this;var a=c.config;this.textarea=this.editor._textArea;a.registerIcon("savesubmitchanged",Xinha.getPluginDir("SaveSubmit")+"/img/ed_save_red.gif");a.registerIcon("savesubmitunchanged",Xinha.getPluginDir("SaveSubmit")+"/img/ed_save_green.gif");a.registerButton({id:"savesubmit",tooltip:b._lc("Save"),image:a.iconList.savesubmitunchanged,textMode:false,action:function(){b.save()}});a.addToolbarElement("savesubmit","popupeditor",-1)}SaveSubmit.prototype._lc=function(a){return Xinha._lc(a,"SaveSubmit")};SaveSubmit._pluginInfo={name:"SaveSubmit",version:"1.0",developer:"Raimund Meyer",developer_url:"http://x-webservice.net",c_owner:"Raimund Meyer",sponsor:"",sponsor_url:"",license:"htmlArea"};SaveSubmit.prototype.onKeyPress=function(a){if(a.ctrlKey&&this.editor.getKey(a)=="s"){this.save(this.editor);Xinha._stopEvent(a);return true}else{if(!this.changed){if(this.getChanged()){this.setChanged()}return false}}};SaveSubmit.prototype.onExecCommand=function(a){if(this.changed&&a=="undo"){if(this.initial_html==this.editor.getInnerHTML()){this.setUnChanged()}return false}};SaveSubmit.prototype.onUpdateToolbar=function(){if(!this.initial_html){this.initial_html=this.editor.getInnerHTML()}if(!this.changed){if(this.getChanged()){this.setChanged()}return false}};SaveSubmit.prototype.getChanged=function(){if(this.initial_html===null){this.initial_html=this.editor.getInnerHTML()}if(this.initial_html!=this.editor.getInnerHTML()&&this.changed==false){this.changed=true;return true}else{return false}};SaveSubmit.prototype.setChanged=function(){this.editor._toolbarObjects.savesubmit.swapImage(this.editor.config.iconList.savesubmitchanged);this.editor.updateToolbar()};SaveSubmit.prototype.setUnChanged=function(){this.changed=false;this.editor._toolbarObjects.savesubmit.swapImage(this.editor.config.iconList.savesubmitunchanged)};SaveSubmit.prototype.changedReset=function(){this.initial_html=null;this.setUnChanged()};SaveSubmit.prototype.save=function(){this.buildMessage();var e=this.editor;var a=this;var g=e._textArea.form;g.onsubmit();var c,h,f="";for(var d=0;d<g.elements.length;d++){if((g.elements[d].type=="checkbox"||g.elements[d].type=="radio")&&!g.elements[d].checked){continue}f+=((d>0)?"&":"")+g.elements[d].name+"="+encodeURIComponent(g.elements[d].value)}var b=e._textArea.form.action||window.location.href;Xinha._postback(b,f,function(i){if(i){a.setMessage(i);a.changedReset()}removeMessage=function(){a.removeMessage()};window.setTimeout("removeMessage()",1000)})};SaveSubmit.prototype.setMessage=function(c){var a=this.textarea;if(!document.getElementById("message_sub_"+a.id)){return}var b=document.getElementById("message_sub_"+a.id);b.innerHTML=Xinha._lc(c,"SaveSubmit")};SaveSubmit.prototype.removeMessage=function(){var a=this.textarea;if(!document.getElementById("message_"+a.id)){return}document.body.removeChild(document.getElementById("message_"+a.id))};SaveSubmit.prototype.buildMessage=function(){var a=this.textarea;var e=this.editor._htmlArea;var d=document.createElement("div");d.id="message_"+a.id;d.className="loading";d.style.width=e.offsetWidth+"px";d.style.left=Xinha.findPosX(e)+"px";d.style.top=(Xinha.findPosY(e)+parseInt(e.offsetHeight)/2)-50+"px";var c=document.createElement("div");c.className="loading_main";c.id="loading_main_"+a.id;c.appendChild(document.createTextNode(this._lc("Saving...")));var b=document.createElement("div");b.className="loading_sub";b.id="message_sub_"+a.id;b.appendChild(document.createTextNode(this._lc("in progress")));d.appendChild(c);d.appendChild(b);document.body.appendChild(d)};