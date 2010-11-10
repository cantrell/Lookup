import com.adobe.protocols.dict.*;
import com.adobe.protocols.dict.events.*;

import flash.events.TextEvent;
import flash.net.SharedObject;

import mx.collections.ArrayCollection;
import mx.controls.Alert;
import mx.events.ValidationResultEvent;
import mx.managers.CursorManager;
import mx.managers.PopUpManager;
import mx.utils.StringUtil;
import mx.events.CloseEvent;
import flash.display.NativeWindow;
import flash.geom.Point;

var dict:Dict;
var connectingDialog:ConnectingDialog;
var currentServer:DictionaryServer;
[Bindable]
var servers:ArrayCollection = new ArrayCollection();

[Bindable]
 var databases:ArrayCollection = new ArrayCollection();
[Bindable]
 var matches:ArrayCollection = new ArrayCollection();
[Bindable]
 var shortDatabaseList:Boolean;
 var matchStrategy:String;
[Bindable]
 var history:ArrayCollection;
 var historyIndex:int;
[Bindable]
 var proxyServer:String = "";
[Bindable]
 var proxyPort:uint = 0;
[Bindable]
 var proxyActive:Boolean = false;
 var prefs:SharedObject;

 var definitionFont:String = "Arial";
 var linkColor:String = "0000ff";
 var fontSize:String = "12";

 function init():void
{
	// Configure the window.
	var win:NativeWindow = this.nativeWindow;
	win.width = 408;
	win.height = 608;
	win.minSize = new Point(408, 608);
	win.visible = true;
	
	dict = new Dict();
	configureEventListeners();
	configurePreferences();
	connectingDialog = new ConnectingDialog();

	// Defaults
	views.selectedChild = matchView;
	progressViews.selectedChild = progressText;
	shortDatabaseList = true;
	matchStrategy = "prefix";
	dict.getServers();
}

 function configureEventListeners():void
{
	// For the Dict object.
	dict.addEventListener(Dict.CONNECTED, connected);
	dict.addEventListener(Dict.DISCONNECTED, disconnected);
	dict.addEventListener(Dict.DATABASES, incomingDatabases);
	dict.addEventListener(Dict.MATCH, incomingMatches);
	dict.addEventListener(Dict.MATCH_STRATEGIES, incomingMatchStrategies);
	dict.addEventListener(Dict.NO_MATCH, noMatches);
	dict.addEventListener(Dict.DEFINITION, incomingDefinition);
	dict.addEventListener(Dict.DEFINITION_HEADER, incomingDefinitionHeader);
	dict.addEventListener(Dict.SERVERS, incomingServers);
	dict.addEventListener(Dict.IO_ERROR, incomingIOError);
	
	// For controls.
	termInput.addEventListener(Event.CHANGE, onTextInput);
	definition.addEventListener(TextEvent.LINK, lookUpWordFromHyperlink);
	databaseList.addEventListener(Event.CHANGE, onTextInput);
	matchList.addEventListener(Event.CHANGE, lookUpWordFromList);
	historyList.addEventListener(Event.CHANGE, lookUpFromHistory);
	backButton.addEventListener(MouseEvent.CLICK, back);
	forwardButton.addEventListener(MouseEvent.CLICK, forward);
	historyButton.addEventListener(MouseEvent.CLICK, showHistory);
	preferencesButton.addEventListener(MouseEvent.CLICK, showConfig);
	serverList.addEventListener(Event.CHANGE, onServerSelect);
}

 function configurePreferences():void
{
	prefs = SharedObject.getLocal("cantrell.lookup.preferences.proxy");
	if (prefs.data.proxyServer != undefined)
	{
		this.proxyServer = prefs.data.proxyServer;
		this.proxyPort = prefs.data.proxyPort;
		this.proxyActive = prefs.data.proxyActive;
	}	
}

 function initiateConnection(e:CloseEvent=null):void
{
	PopUpManager.addPopUp(this.connectingDialog, this, true);
	PopUpManager.centerPopUp(this.connectingDialog);
	this.history = new ArrayCollection();
	this.historyIndex = -1;
	this.backButton.enabled = false;
	this.forwardButton.enabled = false;
	this.historyButton.enabled = false;

	if (this.proxyServer.length != 0 && this.proxyPort != 0 && this.proxyActive)
	{
		dict.connectThroughProxy(this.proxyServer, this.proxyPort, this.currentServer.server);
	}
	else
	{
		dict.connect(this.currentServer.server);
	}

	if (this.matches.length > 0)
	{
		this.matches.removeAll();
	}
	if (this.views.selectedChild != this.matchView)
	{
		this.views.selectedChild = this.matchView;
	}
	this.termInput.text = "";
	this.resultText.text = "Enter a search term";
}

 function onServerSelect(event:Event):void
{
	var desc:String = this.serverList.selectedItem.description;
	desc = this.cleanUpHTML(desc);
	this.serverDescription.htmlText = null;
	this.openFont('serverDescription');
	this.serverDescription.htmlText += desc;
	this.closeFont('serverDescription');
}

 function onTextInput(event:Event):void
{
	if (views.selectedChild != matchView)
	{
		views.selectedChild = matchView;
	}
	var term:String = this.termInput.text;
	if (StringUtil.trim(term).length == 0)
	{
		this.matches.removeAll();
		this.resultText.text = "Enter search term above";
	}
	else
	{
		showLoadingBar(true);
		dict.match(this.databaseList.selectedItem.name, term, this.matchStrategy);
	}
}

 function lookUpWordFromHyperlink(event:TextEvent):void
{
	var term:String = unescape(event.text);
	if (term != termInput.text)
	{
		termInput.text = term;
	}
	this.createHistoryEntry(term);
	this.lookUpWord(term);
}

 function lookUpWordFromList(event:Event):void
{
	var term:String = this.matchList.selectedItem as String;
	if (term != termInput.text)
	{
		termInput.text = term;
	}
	this.createHistoryEntry(term);
	this.lookUpWord(term);
	this.definition.htmlText = "";
	//this.views.selectedChild = definitionView;
	this.matches.removeAll();
}

 function lookUpFromHistory(event:Event):void
{
	this.historyIndex = this.historyList.selectedIndex;
	this.updateSearchUI();
	this.lookUpWord(this.termInput.text);
	//this.views.selectedChild = definitionView;
}

 function lookUpWord(term:String):void
{
	CursorManager.setBusyCursor();
	var db:String = this.databaseList.selectedItem.name;
	this.views.selectedChild = definitionView;
	dict.define(db, term);

	if (this.historyIndex < this.history.length - 1)
	{
		this.forwardButton.enabled = true;
	}
	else
	{
		this.forwardButton.enabled = false;
	}
	
	if (this.history.length > 0 && this.historyIndex > 0)
	{
		this.backButton.enabled = true;
	}
	else
	{
		this.backButton.enabled = false;
	}
}

 function createHistoryEntry(term:String):void
{
	var db:Database = this.databaseList.selectedItem as Database;
	this.historyIndex++;
	history.addItemAt({db:db,term:term}, this.historyIndex);
	if (!historyButton.enabled)
	{
		historyButton.enabled = true;
	}
}

 function forward(event:Event):void
{
	this.historyIndex++;
	this.updateSearchUI();
	this.lookUpWord(this.termInput.text);
}

 function back(event:Event):void
{
	this.historyIndex--;
	this.updateSearchUI();
	this.lookUpWord(this.termInput.text);
}

 function showHistory(event:Event):void
{
	this.views.selectedChild = historyView;
}

 function showConfig(event:Event):void
{
	this.views.selectedChild = configView;
}

 function updateSearchUI():void
{
	var historyEntry:Object = this.history.getItemAt(this.historyIndex);
	this.databaseList.selectedItem = historyEntry.db;
	this.termInput.text = historyEntry.term;				
}

 function connected(event:Event):void
{
	this.dict.getDatabases(this.shortDatabaseList);
}

 function disconnected(event:Event):void
{
	Alert.show("Your connection has been lost. Click OK to reconnect.",
			   "Connection Lost",
			   Alert.OK,
			   null,
			   this.initiateConnection);
}

 function incomingDatabases(event:DatabaseEvent):void
{
	var databases:Array = event.databases;
	this.databases.source = databases;
	// Removing the elements database because of legal concerns
	for (var i:uint = 0; i < databases.length; ++i)
	{
		if (databases[i].name == "elements")
		{
			this.databases.removeItemAt(i);
			break;
		}
	}
	PopUpManager.removePopUp(this.connectingDialog);
	this.termInput.setFocus();
	this.termInput.setSelection(0, this.termInput.length);
}

 function incomingMatchStrategies(event:MatchStrategiesEvent):void
{
	// Alternate match strategies not supported at this time.
}

 function incomingMatches(event:MatchEvent):void
{
	var store:Dictionary = new Dictionary();
	var uniqueMatches:Array = event.matches.filter(
	function (elem:*, index:uint, origArr:Array):Boolean
	{
		if (store[elem] == null)
		{
			store[elem] = "";
			return true;
		}
		return false;
	});
	this.resultText.text = (uniqueMatches.length + " entries found for \""+this.termInput.text+"\"");
	this.matches.source = uniqueMatches;
	showLoadingBar(false);
}

 function incomingDefinitionHeader(event:DefinitionHeaderEvent):void
{
	definition.htmlText = "";
	definition.verticalScrollPosition = 0;
	CursorManager.removeBusyCursor();
}

 function incomingDefinition(event:DefinitionEvent):void
{
	var def:Definition = event.definition;
	var defString:String = def.definition;
	var links:Array = defString.match(/\{[^\}]+\}/g);
	if (links != null)
	{
		for each (var link:String in links)
		{
			defString = defString.replace(link, hyperlink(link));
		}
	}
	defString = this.cleanUpHTML(defString);
	openFont('definition');
	definition.htmlText = defString + "\n\n" + definition.htmlText;
	//definition.htmlText += defString;
	//definition.htmlText += "\n\n";
	closeFont('definition');
}

 function incomingServers(event:DictionaryServerEvent):void
{
	this.currentServer = event.servers[0] as DictionaryServer;
	this.servers.source = event.servers;
	this.onServerSelect(null);
	this.initiateConnection();
}

 function incomingIOError(event:IOErrorEvent):void
{
	this.showLoadingBar(false);
	PopUpManager.removePopUp(this.connectingDialog);
	Alert.show("You either don't have an Internet connection, or you need to configure a proxy to get through your firewall. Click the Preferences button to configure a proxy.", "Connection failed", Alert.OK);
}

 function noMatches(event:NoMatchEvent):void
{
	showLoadingBar(false);
	this.matches.removeAll();
	this.resultText.text = "No matches found.";
}

 function showLoadingBar(show:Boolean):void
{
	if (show)
	{
		this.progressViews.selectedChild = progressBar;
		this.loadingBar.visible = true;
	}
	else
	{
		this.progressViews.selectedChild = progressText;			
		this.loadingBar.visible = false;
	}
}

 function saveConfiguration(event:Event):void
{
	this.currentServer = this.serverList.selectedItem as DictionaryServer;
	this.shortDatabaseList = this.shortListBox.selected;
	this.initiateConnection();
}

 function saveProxySettings(event:Event):void
{
	this.proxyServer = this.proxyServerInput.text;
	this.proxyPort = uint(this.proxyPortInput.text);
	this.proxyActive = this.proxyActiveInput.selected;
	this.prefs.data.proxyServer = this.proxyServer;
	this.prefs.data.proxyPort = this.proxyPort;
	this.prefs.data.proxyActive = this.proxyActive;
	this.prefs.flush();
	this.initiateConnection();
}

 function validateProxySettings(event:Event):void
{
	/*
	if (this.proxyServerValidator.validate(null, true).type == ValidationResultEvent.VALID &&
	    this.proxyPortValidator.validate(null, true).type == ValidationResultEvent.VALID &&
	    this.proxyPortInput.text != "0")
	    {
	    	this.connectButton.enabled = true;
	    }
	    else
	    {
	    	this.connectButton.enabled = false;
	}
	*/
}

 function cleanUpHTML(html:String):String
{
	html = html.replace(/\r|\t/g, ""); // Get rid of \r's
	html = html.replace(/[ ]{2,}/g, ""); // Get rid of consecutive whitespace and tabs
	html = html.replace(/([^\n]{1})\n([^\n]{1})/g, "$1 $2"); // Get rid of unnecessary \n's
	return html;
}

 function hyperlink(href:String):String
{
	href = href.replace(/\{|\}/g, "");
	return "<a href='event:"+escape(href)+"'><font color='#"+this.linkColor+"' face='"+this.definitionFont+"'><u>"+href+"</u></font></a>";
}

 function openFont(textAreaName:String):void
{
	this[textAreaName].htmlText += "<font size='"+this.fontSize+"' face='"+this.definitionFont+"'>";
}

 function closeFont(textAreaName:String):void
{
	this[textAreaName].htmlText += "</font>";
}
