
//+------------------------------------------------------------------+
//|                               xm7_Ccfp_Wkly_TradeMonitor_v66.mq4 |
//|                                    Copyright c 2017, Forexpinbar |
//|                                Author: Forexpinbar (ForexFactory)|
//|                                              Created in Jan 2017 |  
//|                         version v66.0 last updated on 2020.04.93 |
//+------------------------------------------------------------------+ 

//updated AllowHedge functions when new trades are added

#property copyright "Copyright © 2017-2020, xm7 Ccfp Weekly TradeMonitor v66.0"
#property strict

string version_str="v65.0";
string DisplayTitle="= xm7 CCFp-Diff Monitor "+version_str+" =";

#include <xm7/UserAgreement.mqh>
#include <xm7/profitCalculations.mqh>
#include <xm7/xm7-http.mqh>
#include <stderror.mqh>
#include <stdlib.mqh>

#import "shell32.dll"
   int ShellExecuteW(int hWnd, string Verb, string File, string Parameter, string Path, int ShowCommand);
#import

enum dow { Sunday=0, Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5, Saturday=6};
enum tpType { Pips, Percent };
enum revtype { None, ReverseAll, ReverseFromFxMadnessIndicator } ;
enum rStart { Weekly, Daily, Monthly }; 
enum LotType { Fixed, LotsPerBalance }; //{ Fixed, LotSizeBasedOnRisk, LotsPerBalance };
enum tf_type { Current=0, M1=PERIOD_M1, M5=PERIOD_M5, M15=PERIOD_M15, H1=PERIOD_H1, H4=PERIOD_H4, D1=PERIOD_D1, WK1=PERIOD_W1, MN1=PERIOD_MN1 } ;
enum p_trail { NoTrail,TrailStop,oneTimeBE }; //PercentOfProfit
enum tmark { DoNotCheck,Check_DD,Check_DDorProfit };
enum showmsg_type { noBeginLockProfit,lowLockPOP,lowLockManual };
enum dlogs { daily, weekly, monthly, doNotDelete };

extern int MagicNumber=1; //Basket Magic Number
extern string TradeComment = "CCfp_Basket";
extern rStart TradeMode=Weekly;
extern string SetHours="===================="; //=== OPEN/CLOSE HOURS(s) (Applies to all Trade Modes) ===
extern string GMTOpenHour="00:00"; //OpenHour ("HH:mm" or "HH:mm,HH:mm,.." or "HH:mm-HH2:mm,HH:mm-HH2:mm,..") "Manual" = Ignore
extern string GMTFridayCloseHour="19:50";//Friday Close ("HH:mm"). "-" = Ignore Hour
extern bool ShowTimeMinMax=false;  //Include Date/Hours when Min/Max is recorded
extern double MarginLevel=150; //Lowest %margin allowed to open new trades 
extern bool SortByStrength=false; //Sort Suggested Pairs by Strength

extern string LotSizeOptions="====================";//=== LOTSIZE OPTIONS ===
extern LotType LotSizing = Fixed;
extern double FixedLotSize= 0.01; // Lot Size
extern string Lots_Per_Balance="0.01/100";

extern string checkHourMark="====================";//=== CLOSE OPENED BASKET BASED ON TIME/CHECKING DD/PROFIT  ===
extern tmark selectMarkOption=DoNotCheck;//Select what to Check
extern int checkProfitStatusMins=0; //When to check, enter in minutes (0=ignore)
extern bool resetVirt=false; //If no virtualBasket trigger, reset it

extern string Targets="===================="; //=== BASKET STOPLOSS/TAKEPROFIT ===
extern tpType Use_SL_TP_Locks_As=Pips;//Use Pips or % for SL/TP Values
extern double Take_Profit=0; //Take_Profit Basket (pips or %)
extern double Stop_Profit=0; //Stop_Loss Basket (pips or %)

extern string Weekly_Settings="===================="; //=== SETTING FOR WEEKLY TRADEMODE ===
extern dow GMTOpenDayofWeek = Monday; // Day of Week to Open Basket

extern string Daily_Settings="===================="; //=== SETTING FOR DAILY TRADEMODE ===
extern string GMTDailyCloseHour="23:50"; //Daily Hour to Close Basket ("HH:mm", "-" = Ignore Hour)
extern string NoTradeDays="";//No Tradedays ("Monday,Wednesday,... etc);

extern string Monthly_Settings="===================="; //=== SETTING FOR MONTHLY TRADEMODE ===
extern int GMTDayOfMonth=1; //Day of Month To open basket (1,2,3...28 or 30 or 31)

input string LockProfit="====================";//=== TRAIL STOP FOR BASKET SETTINGS (pips or %) ===
extern p_trail StepFactor=NoTrail; //Select: TrailStop,oneTimeBE,NoTrail 
extern double setStartLocking=0; //setStartLocking, Tells it when to START locking (% or pips):
input string TrailParameters="====================";//--- Inputs for TrailStop --- 
extern double setLockDelta=0; //StepDelta, for trail stop (% or pips)
extern double _TrailStop=0; //TrailStop (% or pips)
extern bool SetBEonFirstTrail=false;
input string manualBEstop="====================";//--- oneTime BE overrides TrailStop --- 
extern double beLock=0; //One Time BE Lock (Select: oneTimeBE):

extern string TradeControl0="====================";//===  TRADE CONTROL SETTINGS ===
extern int MaxTradesAllowed=0;
extern string TradeControl1="====================";//===  TRADE CONTROL BEFORE REAL BASKET IS OPENED ===
extern bool AllowDuplicates=false; //Allow Duplicates from Indicator Lists(s)
extern bool removeALLDuplicates=false; //if AllowDuplicates=false, remove both symbols
extern bool AllowOpposites=false; //Allow Hedges from Indicator Lists(s)
extern string TradeControl2="====================";//===  TRADE CONTROL AFTER REAL BASKET IS OPENED ===
extern revtype ReverseSignals=None; //Reverse All Trade Suggestions and open in Basket
extern bool AllowNewTradesToBasket=false; //Add new Trade Suggestions on realBasket
extern bool AllowNewTradesOnlyIfBasketPositive=false; //Only add new Trades if Basket is positive
extern bool FlipSignalIfTradeOpposite = false; //Flip existing trade if new Trade is opposite type
extern bool AllowNewTradeDuplicates=false; //Allow new Duplicates into realBasket
extern bool AllowHedgeRealTrades = false; //Allow new Hedges into Basket
extern string rbasket_timeLimits="===================="; //=(realBasket hours of operation)=
extern int rBasketProcessingHours=0;//Close realBasket after X Hrs
 
extern string Virtual="====================";//=== VIRTUAL BASKET SETTINGS ===
extern bool UseVirtualBasket=false;
extern double VirtualUpperTriggerLevel=0.0; //vBasket Upper Trigger Level(pips)
extern double VirtualLowerTriggerLevel=0.0; //vBasket Lower Trigger Level(pips)
extern double VirtualBounceTrigger=0;
extern bool showVirtMaxMinPipLimits=true;//Show Max Min vBasket Pip Gains
extern int MaxVirtTradesAllowed=0;
extern bool OnlyPositivetvTradesToRBasket=false; //Only Allow + profit vTrades to open in real basket
extern double minPipsToRBasket=0.0; //Pip threshold (0=allow only positive);
extern bool applyRealtoVB=false; //Apply filters continuously to vTrades
extern string vbasket_timeLimits="===================="; //=(virtualBasket hours of operation)=
extern int vBasketHoursOfOperation=0; //Close virtBasket after X hrs (only if rBasket not triggered)
extern bool continueProcessingVB=false; //Once Opened refresh virtualBakset every second

extern string NegTriggerApproach="====================";//=== NEGATIVE TRIGGER SETTINGS ===
extern bool letEASetNegTrig=false; //Let EA set the negative trig based on open vbasket trades
extern string basketNumberOfTrades = "1-5,6-10,11-14,15-Greater"; //# of vTrades, 1 to 5, 6 to 10  etc
extern string negativeTriggers ="-150,-250,-350,-450"; //Negative triggers, 1-5 is -150, 5-10 is -250 etc

extern string ATRTargets="== NOTE: TP/SL ARE RECALCULATED IN PIPS =="; //=== ATR STOPLOSS ===
extern double TP_to_SL_Ratio=0; //TP/SL Ratio 1:1, 2:1 .. (0 ==> TP=0)
extern bool InvertRatio=false; //Invert Ratio to SL/TP
extern bool Use_ATR=false; //Set SL to ATR (pips)
extern int ATRPeriod=14; //Set ATR Period 
extern tf_type ATRTimeFrame=Current; //ATR TimeFrame
extern double ATR_Multiplier=0.8; //ATR Multiplier (Adjusts total of ATR stoploss)

extern string IndividualTargets="===================="; //=== FIXED STOPLOSS/TAKEPROFIT PER PAIR SETTINGS ===
extern double IndividualTrades_Take_Profit=0; //IndividualTrades_Take_Profit (pips)
extern double IndividualTrades_Stop_Loss=0; //IndividualTrades_Stop_Loss (pips)
double Set_TrailingStop_On_EachTrade=0; //Set_TrailingStop_On_EachTrade (pips)

extern string Alerts="====================";//=== ALERT SETTINGS ===
extern double SetPipLevelForAlerts=0.0; //SetPipLevelForAlerts (+pips or -pips)
extern bool PopUp = false;
extern bool Send_Notification=false;

extern string Filters="====================";//=== ADDITIONAL FILTERS ===
extern bool TestCandleColors=false; // Check Candle Color Trend
extern string CandleColorsTimeFrames="H4,D1,W1";  //CandleColor TFs separate by comma(from 1 to 3 Tfs)
extern bool UseBBSqueeze=false;// Use BBSequeeze
extern tf_type BBSqueezeTF=H4;

extern string Auxilary="====================";//=== AUXILARY SETTINGS ===
extern string fontType="Arial";
extern bool stopOrderCloseTrades=false; //Allow EA to CloseBasket with BUYSTOP ORDER of +500 pips
extern string disallowPairsCurrencies="None"; //Exclude Pairs or Currencies (EURUSD,AUDUSD,GBP,NZD...).
extern bool UseInitialPairsAtTrigger=false;  //Use Initial vTradeSuggestions when EA opens RealBasket
extern bool LogData=false; //LogData (profit,max,min)
extern dlogs deleteLogsFrequency=doNotDelete;
extern bool IgnoreCloseHourIfDD=false;//Ignore CloseHour if in DD
//extern bool CorrectForVPSHourShifting=false; //Check VPS GMTshift (only use when VPS has hour problems)
extern bool debugInfo=false; //debugInfo (debug Pairs/virtual basket detection)
extern bool debugTime=false; //debugTime (monitor openTime, Clock)
extern bool debugTrades=false; // debugTrades (monitor open trades)
extern bool debugFilter=false; // debugFilters (monitor filters)


struct dynArray { string symbol; string basketid; int optype; int buysellcnt; double strength; double vprice; double vprofit; };

dynArray _pairs[];
dynArray _virtualOrders[];

datetime timeGMT,_virtualbasketclosedTime;
datetime _xm7_rBasketOpenHour,_xm7_vBasketTriggeredHour,_xm7_RealBasketClosedHr;
datetime timer_exec,timer_broker;

int DisplayFontSize=12,y_fontsizebtn,vhours,rhours,tradeListOnChart;
int x_btn,y_btn,btn_width, btn_heigth,dgtz,mainLength; 
int chartH, chartW, DstChk=0,_xm7_IgnoreAllCloseHours;

double total_pips,total_profit;
double virtual_profit,vHighest_pips,vLowest_Pips;
double myTickValue,margin,_basket_take_profit,_basket_stop_profit,_basket_oneTimeBE_value;
double _individualTrades_stop_profit,_individualTrades_take_profit;
double _basket_stop,_xm7_max_week_gain,_xm7_min_week_gain;
double brokerGMToffSet=0, localGMToffSet=0,_VirtualUpperTriggerLevel,_VirtualLowerTriggerLevel;
double _xm7_pipcount,_xm7_currgain,lot_min, lot_max,lot_step;

long _xm7_ea_chartid,_xm7_ind_chartid,_xm7_global_ind_chartid;

bool SkipBinaryPairs,IsMarketOpen,vBTrigged_butNoTrades,rBTrigged_butNoTrades;
bool trd,B1Done,vTriggerHigh,vTriggerLow,_continueVBMonitor;
bool _lock_trig,discreteOpenHours,_basketisclosed;
bool AlertSent,OpenNow,OpenVirt,cc_filter_fail,bbsq_filter_fail;
bool minimized_display_panel,minimized_virtual_panel;

string vMaxTime,vMinTime,gmt_FridayCloseTime;
string _xm7_maxTime,_xm7_minTime,user_openTimeStr,user_closeTimeStr;
string BrokerPairs[],suffixPairs[],LogFileName="",_xm7_magicnumber_str;
string _xm7_TradeComment;
string pipsGain="0",currentGain="0",daysGain="0",weeksGain="0",monthGain="0",yearGain="0";
string daypips="0",weekspips="0",monthpips="0",yearpips="0";
string virtual_trades_list,xm7_comments;
string Prefix="",Suffix="", prfxSymbols[],sufxSymbols[],_Symbol_;
string discreteOpen[],discreteClose[];
string DailyStartTime, gmt_closeTime;

color  FontColor = Gray;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()  {  

   if(!UserAgreement(WindowExpertName()+".ex4")) return(INIT_FAILED);
    
   if(IsDllsAllowed()){ //Wierd I had to do it this way, other way it didnt work
   } else { ShowTxtMessage("dllnotallowed"); return(INIT_FAILED);}

   RemoveObjects("xm7"); 
            
   initVariables();
  
   GetGlobalValues();

   if(!IsDuplicateMagicNumber()) {
       return(INIT_FAILED);
   } else {
       GlobalVariableSet("xm7_ea_chartid_"+_xm7_magicnumber_str+"_"+(string)_xm7_ea_chartid,MagicNumber);              
   }   

    if(!IsTesting()) {  
          GetGMTInfo(localGMToffSet,brokerGMToffSet);
     } else if(IsTesting()) brokerGMToffSet=0;
 
   timeGMT=(int)(TimeCurrent()-brokerGMToffSet*PERIOD_H1*60);        

   IsMarketOpen=true;
   if(checkIfWeekend()) IsMarketOpen=false;

   switch(TradeMode){
      case(Weekly): DisplayTitle="== xm7 Weekly Monitor "+version_str+" =="; break;
      case(Daily): DisplayTitle="== xm7 Dayly Monitor "+version_str+" =="; break;
      case(Monthly): DisplayTitle="== xm7 Monthly Monitor "+version_str+" =="; break;
   }  
    
   ChartSetInteger(_xm7_ea_chartid, CHART_SHOW_ONE_CLICK, false); //DisableOneClick  
   ChartSetInteger(_xm7_ea_chartid, CHART_DRAG_TRADE_LEVELS, false); // disable trade level movement
   ChartSetInteger(_xm7_ea_chartid, CHART_FOREGROUND, false); // disable 'chart in foreground'
   ChartSetInteger(_xm7_ea_chartid, CHART_SHIFT, true); // enable chart shift
      
   DetermineProfit(MagicNumber,_xm7_magicnumber_str,0,daysGain,daypips,weeksGain,weekspips,monthGain,monthpips,yearGain,yearpips);             
   ShowDisplay(pipsGain,currentGain,daysGain,weeksGain,monthGain,yearGain,mainLength);       
   if(_OrdersTotal()>0) {
      OpenNow=true;  B1Done=true;    
   }

   //See if a virtual basket is already opened and rebuilt it  
   if(!IsTesting() && UseVirtualBasket && FileIsExist("virtualOrders_"+_xm7_magicnumber_str)) {        
    
       ArrayFree(_virtualOrders);    
       recoverVirtualArray("virtualOrders_"+_xm7_magicnumber_str,_virtualOrders);

       if(ArraySize(_virtualOrders)>0) {
                
               if(_xm7_rBasketOpenHour==0 || continueProcessingVB) MonitorOpenVirtualTrades();
                                              
               if(letEASetNegTrig) { _VirtualUpperTriggerLevel=0; _VirtualLowerTriggerLevel=MathAbs(getNegativeTrigger(ArraySize(_virtualOrders))); }                 

               if(vBTrigged_butNoTrades) OpenNow=true; //in Case there was a prev trigger but no Trades, need this set to true so new trades execute.
                
               if(!vBTrigged_butNoTrades) {
                     if(!vTriggerHigh && _VirtualUpperTriggerLevel>0 && virtual_profit>_VirtualUpperTriggerLevel) {
                            vTriggerHigh=true; GlobalVariableSet("xm7_vTriggerHigh_"+_xm7_magicnumber_str,1); 
                            if(_OrdersTotal()==0) { vBTrigged_butNoTrades=true; GlobalVariableSet("vBtrigged_butNoTrades"+_xm7_magicnumber_str,1); }
                     }   
                     
                     if(!vTriggerLow && _VirtualLowerTriggerLevel>0 && virtual_profit<-_VirtualLowerTriggerLevel) {
                            vTriggerLow=true; GlobalVariableSet("xm7_vTriggerLow_"+_xm7_magicnumber_str,1);
                            if(_OrdersTotal()==0) { vBTrigged_butNoTrades=true; GlobalVariableSet("vBtrigged_butNoTrades"+_xm7_magicnumber_str,1); }
                     }
               }

               if(_virtualbasketclosedTime!=0) ArrayFree(_virtualOrders);   //time that vBasket was to close             
                
               //===========  Check if a new day has passed, if so reset everything and delete virt file and return.
               if(!continueProcessingVB) 
                     if(TimeDay(_xm7_vBasketTriggeredHour)!=TimeDay(timeGMT) && _OrdersTotal()==0) {
                           FileDelete("virtualOrders_"+_xm7_magicnumber_str);
                           resetVirtualBasketVariables(); 
                     }                     
           } 

   }      
   
   if(UseVirtualBasket) ShowVirtualBasket(mainLength);

   if(GlobalVariableCheck("xm7_DstChk")) {
      DstChk=(int)GlobalVariableGet("xm7_DstChk");
   } else {
      GlobalVariableSet("xm7_DstChk",0);
   } 
    
   if(GMTDayOfMonth>31) GMTDayOfMonth=1;
             
   if(!IsTradeAllowed()) ShowTxtMessage("tradeAllowed");
  
   //===  Check that indicators are found and ready for EA  ==================
   //if(!IsTesting() && tradeListOnChart==0) {  ShowTxtMessage("missingIndi"); return(INIT_FAILED);  }   

  _xm7_TradeComment=TradeComment; 
  if(_xm7_TradeComment=="") {
      if(TradeMode==Weekly) _xm7_TradeComment="CCfp_Weekly_Basket";
      if(TradeMode==Daily) _xm7_TradeComment="CCfp_Daily_Basket";
  }
                                                                         
   if(Use_ATR && _OrdersTotal()>0) GetBasketStopTake(_basket_stop_profit,_basket_take_profit);
   
   if(TP_to_SL_Ratio>0 && _basket_stop_profit>0) _basket_take_profit=_basket_stop_profit*TP_to_SL_Ratio;
   if(InvertRatio && TP_to_SL_Ratio>0 && _basket_stop_profit>0) _basket_take_profit=_basket_stop_profit/TP_to_SL_Ratio;  
 
  if(vBasketHoursOfOperation>0) vhours=vBasketHoursOfOperation*PERIOD_H1*60;
  if(rBasketProcessingHours>0) rhours=rBasketProcessingHours*PERIOD_H1*60;  
 
   //message user of any incorrect profit lock inputs
   if(StepFactor!=NoTrail && !_lock_trig){
         if(StepFactor==oneTimeBE && setStartLocking<=beLock) ShowMessage(lowLockManual); 
   }
   
   if(CandleColorsTimeFrames!="") 
       if(CheckTFString(CandleColorsTimeFrames)) ShowTxtMessage("CandleTF");       
     
   //EventSetTimer(1);
   if(!IsTesting()) 
      if(!SetEventTimer(1)) return(INIT_FAILED);
 
   Print("Ccfp EA with magic# ",MagicNumber," initialized.");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
 
   bool found_open_basket=false; 
   int ObjCount=GlobalVariablesTotal();

   if(!IsTesting())
      if(ArraySize(_virtualOrders)>0)
            backupVirtualArray("virtualOrders_"+_xm7_magicnumber_str);
            
   if(_OrdersTotal()==0) RemoveGlobals("_"+_xm7_magicnumber_str,"xm7_cmnts_"+_xm7_magicnumber_str); // RemoveGlobals() removes all except xm7_cmnts and Offset stuff  
         
   if(GlobalVariableCheck("xm7_pipcount_"+_xm7_magicnumber_str)) found_open_basket=true;    
     
   if(!found_open_basket && GlobalVariableCheck("xm7_ea_chartid_"+_xm7_magicnumber_str+"_"+(string)_xm7_ea_chartid)) {
        GlobalVariableDel("xm7_ea_chartid_"+_xm7_magicnumber_str+"_"+(string)_xm7_ea_chartid); 
        GlobalVariableDel("xm7_ind_chartid_"+_xm7_magicnumber_str+"_"+(string)_xm7_ind_chartid); 
   }    
  
   RemoveObjects("xm7"); 

   EventKillTimer();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   if(!GlobalVariableCheck("xm7_ea_chartid_"+_xm7_magicnumber_str+"_"+(string)_xm7_ea_chartid))
         GlobalVariableSet("xm7_ea_chartid_"+_xm7_magicnumber_str+"_"+(string)_xm7_ea_chartid,MagicNumber);   

   if(LogData && _OrdersTotal()==0) //check to see if logs need to be removed
       if(IsNewGMTDayLog()) removeLogs();     

    if(TimeLocal()>timer_exec+2) OnTimer(); //If timer stops we can continue monitoring the balance and stuff like this.      
   
   //Reset virtual basket if not triggered
   if(UseVirtualBasket)
      if((TradeMode==Daily && IsNewGMTDay()) || (TradeMode==Weekly && IsNewWeek()) || (TradeMode==Monthly && IsNewMonth())) {
         if(!continueProcessingVB && ArraySize(_virtualOrders)>0 && _OrdersTotal()==0 && vhours==0 && rhours==0) resetVirtualBasketVariables(); 
         if (ArraySize(_virtualOrders)==0 && _OrdersTotal()==0) gmt_closeTime=""; 
         if (gmt_closeTime!="" && (ArraySize(_virtualOrders)>0 || _OrdersTotal()>0))
               if(timeGMT-StringToTime(gmt_closeTime)>PERIOD_D1*60) 
                     gmt_closeTime = TimeToStr(timeGMT,TIME_DATE)+" "+GMTDailyCloseHour; //update gmt_closeTime to new day close hour
      }           

   if(IsTesting()) OnTimer();
     
  }

void OnTimer() {

   if(timer_exec!=TimeLocal()) timer_exec=TimeLocal();
   
   timeGMT=(int)(TimeCurrent()-brokerGMToffSet*PERIOD_H1*60);   
   
   IsMarketOpen=true;
   if(checkIfWeekend()) IsMarketOpen=false;  
   
   //This allows for display to be drawn IF no reset button is found yet market is closed
   if(ObjectFind(_xm7_ea_chartid,"xm77_ResetButton_"+(string)_xm7_ea_chartid)==0 && !IsMarketOpen) return;

   DetermineProfit(MagicNumber,_xm7_magicnumber_str,0,daysGain,daypips,weeksGain,weekspips,monthGain,monthpips,yearGain,yearpips); // get current/daily/weekly etc % gains 
   
   if(ArraySize(discreteOpen)>0) SeperateOpenClose(timeGMT,user_openTimeStr,user_closeTimeStr); //update any multi open hrs
   
   ShowDisplay(pipsGain,currentGain,daysGain,weeksGain,monthGain,yearGain,mainLength);       
   if(UseVirtualBasket) ShowVirtualBasket(mainLength);  

   if(IsMarketOpen) pl_start();
}

void setCloseHours() {

      if(GMTFridayCloseHour!="-") gmt_FridayCloseTime = TimeToStr(timeGMT,TIME_DATE)+" "+GMTFridayCloseHour;
      
      if(GMTDailyCloseHour!="-") gmt_closeTime = TimeToStr(timeGMT,TIME_DATE)+" "+GMTDailyCloseHour;
      if(StringToTime(gmt_closeTime)<=StringToTime(TimeToStr(timeGMT,TIME_DATE)+" "+GMTOpenHour)) 
            gmt_closeTime=TimeToStr(StringToTime(gmt_closeTime)+PERIOD_D1*60); 
  
      if(ArraySize(discreteClose)>0) {
         gmt_closeTime = TimeToStr(timeGMT,TIME_DATE)+" "+user_closeTimeStr;
         if(GMTDailyCloseHour!="-")
            if(TimeToStr(timeGMT,TIME_DATE)+" "+GMTDailyCloseHour<=gmt_closeTime)
                  gmt_closeTime = TimeToStr(timeGMT,TIME_DATE)+" "+GMTDailyCloseHour;
       }
      
      if(ArraySize(discreteOpen)>0) _xm7_IgnoreAllCloseHours=false; //Do not ignore close hours for discrete (multiple) hours
}


void monitorAlerts() {
      if(SetPipLevelForAlerts!=0) {
         if(!AlertSent && _OrdersTotal()>0){
             if((total_pips>0 && SetPipLevelForAlerts>0 && total_pips>SetPipLevelForAlerts) || (total_pips<0 && SetPipLevelForAlerts<0 && total_pips<SetPipLevelForAlerts)) { 
               alerts(_xm7_magicnumber_str,(string)total_pips);
               AlertSent=true; GlobalVariableSet("xm7_AlertSent_"+_xm7_magicnumber_str,1);
             }   
         } 
         
         if(AlertSent && _OrdersTotal()==0) { AlertSent=false; GlobalVariableDel("xm7_AlertSent_"+_xm7_magicnumber_str); } 
      }    
}

void pl_start(){
   
   double currentBasketProfit=0,_AccountBalance=0;
   string result[];
   
   monitorAlerts();      

//==Check if we open a real basket
  if(!UseVirtualBasket) 
     if(_OrdersTotal()==0) {
         OpenNow=false;
         if(AllowTradesByTime()) OpenNow=true;   
         if(OpenNow){ 
             resetAllVariables(); 
             if(LogData) SetLogFile(LogFileName);
             setCloseHours();
             GetPairs(); OpenBasket(); return; 
         }
     }    

//==Check to see if we open a virtual basket
  if(UseVirtualBasket){   
     if(ArraySize(_virtualOrders)==0) {
           OpenVirt=false;
           if(AllowTradesByTime()) OpenVirt=true; 
              if(OpenVirt || _continueVBMonitor) { //_continueVBMonitor is for EA to continue monitoring suggestList even though there was no 1st vBasket
                  resetAllVariables();
                  _xm7_RealBasketClosedHr=0; GlobalVariableDel("xm7_RealBasketClosedHr_"+_xm7_magicnumber_str); 
                  setCloseHours(); 
                  OpenVirtualTrades();  //Note get list of pairs is in this function
                  if(ArraySize(_virtualOrders)>0) {
                        if(letEASetNegTrig) { _VirtualUpperTriggerLevel=0; _VirtualLowerTriggerLevel=MathAbs(getNegativeTrigger(ArraySize(_virtualOrders))); } 
                        _xm7_vBasketTriggeredHour=timeGMT; GlobalVariableSet("xm7_vBasketTriggerHour_"+_xm7_magicnumber_str,(double)_xm7_vBasketTriggeredHour);
                        if(!IsTesting()) backupVirtualArray("virtualOrders_"+_xm7_magicnumber_str);
                        if(_continueVBMonitor) { _continueVBMonitor=false;  GlobalVariableDel("xm7_continueVBMonitor_"+_xm7_magicnumber_str); }
                  } else if (continueProcessingVB){
                        if(!_continueVBMonitor) { _continueVBMonitor=true; GlobalVariableSet("xm7_continueVBMonitor_"+_xm7_magicnumber_str,1); }
                  }
              }
     }         

     if(ArraySize(_virtualOrders)>0 && _OrdersTotal()==0){ 

           MonitorOpenVirtualTrades();

           if(selectMarkOption!=DoNotCheck && resetVirt)
               if(chkHrVirtualMark()) return;
            
           if(!continueProcessingVB) // this is set by user or continueProcessingVB
              if((GMTDailyCloseHour!="-" && TradeMode==Daily) || ArraySize(discreteOpen)>0) //==Check CloseHour vBasket
                         if(timeGMT>=StringToTime(gmt_closeTime)) 
                           { ArrayFree(_virtualOrders); vBTrigged_butNoTrades=true; _virtualbasketclosedTime=TimeGMT(); gmt_closeTime=""; return; }          
                
           if(GMTFridayCloseHour!="-" && TimeDayOfWeek(timeGMT)==5) //==Check Friday CloseHour
                     if(timeGMT>=StringToTime(gmt_FridayCloseTime)) { resetVirtualBasketVariables(); gmt_closeTime=""; return; } 
                     
           //Hours of duration for virtual basket 
           if(vhours>0 && timeGMT-_xm7_vBasketTriggeredHour>=vhours) { resetVirtualBasketVariables(); gmt_closeTime=""; return; }                      
                
           if(!OpenNow && !vBTrigged_butNoTrades) {
      
                  if(!vTriggerHigh && _VirtualUpperTriggerLevel>0 && virtual_profit>_VirtualUpperTriggerLevel) {
                        vTriggerHigh=true; GlobalVariableSet("xm7_vTriggerHigh_"+_xm7_magicnumber_str,1);
                  }   
                  if(!vTriggerLow && _VirtualLowerTriggerLevel>0 && virtual_profit<-_VirtualLowerTriggerLevel) {
                        vTriggerLow=true; GlobalVariableSet("xm7_vTriggerLow_"+_xm7_magicnumber_str,1);
                  }
                     
                  if(vTriggerHigh || vTriggerLow) { 
                        if(VirtualBounceTrigger==0) { 
                             OpenNow=true;
                        } else { 
                             if(vTriggerLow) {
                                 if(VirtualBounceTrigger>0 && virtual_profit>=-_VirtualLowerTriggerLevel+VirtualBounceTrigger) OpenNow=true;
                                 if(VirtualBounceTrigger<0 && virtual_profit<=-_VirtualLowerTriggerLevel-VirtualBounceTrigger) OpenNow=true;
                             }
                             
                             if(vTriggerHigh) { 
                                 if(VirtualBounceTrigger>0 && virtual_profit>=_VirtualUpperTriggerLevel+VirtualBounceTrigger) OpenNow=true;
                                 if(VirtualBounceTrigger<0 && virtual_profit<=_VirtualUpperTriggerLevel-VirtualBounceTrigger) OpenNow=true;
                             }
                       }   
                  }

                  if(OpenNow) { 
                        if(!UseInitialPairsAtTrigger) GetPairs();
                        if(LogData) SetLogFile(LogFileName);
                        setCloseHours();
                        OpenBasket(); return; 
                  }                                                     
            }                                 
      }                
  }
  

//==Basket already open, check profits, max, mins, profitLocks, marker close etc
   if(_OrdersTotal()>0){ 
      
      //Check if user is using BUYSTOP (+500 pips) to close basket.  Usefull when you can only send one message on cell phone app
      if(stopOrderCloseTrades) { emergencyCloseAll(); return; }

      //rhours ALLOW for continued monitoring of vBasket after real basket TRIGGERED. Once HOURS are up vBasket Monitoring is Stopped(Thor(I thnk).
      //continueProcessingVB: user wantes the EA to continue monitoring vb indefinitely(or until it hist the usual close stops).
      if(UseVirtualBasket) 
         if(rhours>0 || continueProcessingVB) 
              if((rhours>0 && timeGMT-_xm7_rBasketOpenHour<rhours) || continueProcessingVB) {
                  MonitorOpenVirtualTrades(); setCloseHours(); OpenBasket();
              }

      _AccountBalance=AccountBalance();
      if(AccountCredit()>0) _AccountBalance=AccountBalance()+AccountCredit();
   
      runningProfit(total_pips,total_profit);  // Get current running pips/profits etc
      
      _xm7_pipcount=NormalizeDouble(total_pips,1); GlobalVariableSet("xm7_pipcount_"+_xm7_magicnumber_str,_xm7_pipcount); 
      _xm7_currgain= NormalizeDouble(((total_profit/_AccountBalance)*100),2); GlobalVariableSet("xm7_currgain_"+_xm7_magicnumber_str,_xm7_currgain);
      currentGain=DoubleToStr(_xm7_currgain,2);  
      pipsGain=DoubleToStr(_xm7_pipcount,1);
       
      //Determine if basket gain in pips or %
      if(Use_SL_TP_Locks_As==Pips) { currentBasketProfit=_xm7_pipcount; } else { currentBasketProfit=_xm7_currgain; }  
      if(Use_ATR) currentBasketProfit=_xm7_pipcount; //if useATR only use pips. 

      //If after 'checkProfitStatusMins' minutes and profit<=0 close basket
       if(selectMarkOption!=DoNotCheck && !_lock_trig) 
            if(chkHrMark(currentBasketProfit)) return;
      
      discreteOpenHours=false;
      
      if(ArraySize(discreteOpen)>0)
            if(AllowTradesByTime()) discreteOpenHours=true;

      bool maxedout=false;
      if(MaxTradesAllowed>0)
            if(_OrdersTotal()>=MaxTradesAllowed) maxedout=true; 
      
      if(!maxedout && rhours==0 && (AllowNewTradesToBasket || discreteOpenHours)) {  
            if(AllowNewTradesOnlyIfBasketPositive && currentBasketProfit>0) { GetPairs(); setCloseHours(); OpenBasket(); }         
            if(!AllowNewTradesOnlyIfBasketPositive && AllowNewTradesToBasket) { GetPairs(); setCloseHours(); OpenBasket(); } 
      }
            
      //Determine Max/Min
      GetMinMax_week(currentBasketProfit,_xm7_max_week_gain,_xm7_min_week_gain,_xm7_maxTime,_xm7_minTime);

      //Log info to file     
      if(LogData)  //Log every x time, pip counts 
         if(NewTFBar(PERIOD_M1)) LogToFile(LogFileName,getTimeMin(timeGMT),(string)total_pips,(string)_xm7_max_week_gain,(string)_xm7_min_week_gain);
 
//==Basket TP/SL ========================          
      if (_basket_stop_profit!=0 || _basket_take_profit!=0) {//Print(currentBasketProfit," <= ",-_basket_stop_profit,"  ",currentBasketProfit<=-_basket_stop_profit);
          if((_basket_take_profit>0 && currentBasketProfit>=_basket_take_profit) || (_basket_stop_profit>0 && currentBasketProfit<=-_basket_stop_profit)) {
                CloseBasket(); return;
         }                 
      }
      
//==Attempt to trail the individual trades.  May not work or not appropriate since this defeats the Basket concept.
      if(Set_TrailingStop_On_EachTrade>0) {
          for(int x=0; x<OrdersTotal(); x++) {
               if(!OrderSelect(x,SELECT_BY_POS)) continue; 
               if(OrderMagicNumber()!=MagicNumber) continue;
               MonitorTrailingStopEachTrade();
          }       
       }               

// TrailStop: Detect if setStartLocking trigger level has been reached ===============       
      if(StepFactor!=NoTrail && setStartLocking>0) {
            if(currentBasketProfit>setStartLocking && !_lock_trig)
                { _lock_trig=true; GlobalVariableSet("xm7_basket_lock_trig_"+_xm7_magicnumber_str,1); }
            
            if(_lock_trig) {
 
                  if(StepFactor==oneTimeBE) { 
                     if(_basket_stop==-1) _basket_stop=MathAbs(_basket_oneTimeBE_value); 
                  } else {
                     MonitorTrailingBasket(currentBasketProfit,_basket_stop);                  
                  }      
                  
                  if(_basket_stop>-1 && currentBasketProfit<=_basket_stop) 
                     { CloseBasket(); return; }
            }                                              
      }

      if(IgnoreCloseHourIfDD && currentBasketProfit<0) _xm7_IgnoreAllCloseHours=true;

      //==Check Daily Close  
      if(!_xm7_IgnoreAllCloseHours && GMTDailyCloseHour!="-" && (TradeMode==Daily || ArraySize(discreteOpen)>0))
           if(timeGMT>=StringToTime(gmt_closeTime)) CloseBasket();

      //==Check Friday Close
      if(!_xm7_IgnoreAllCloseHours && GMTFridayCloseHour!="-")  
            if(TimeDayOfWeek(timeGMT)==5 && timeGMT>=StringToTime(gmt_FridayCloseTime)) CloseBasket(); 
   } // End if _OrdersTotal()>0
   
}

bool NewTFBar(int period) {
   static datetime lastbar;
   if(lastbar!=iTime(_Symbol_,period,0)){
      lastbar=iTime(_Symbol_,period,0);
      return (true);
   }
   return(false);
} 

bool NewDstChkBar(int period){
   static datetime lastbar;
   if(lastbar!=iTime(_Symbol_,period,0)){
      lastbar=iTime(_Symbol_,period,0);
      return (true);
   }
   return(false);
} 

bool NewBar1(int period){
   static datetime lastbar;
   if(lastbar!= iTime(_Symbol_,period,0)){
      lastbar= iTime(_Symbol_,period,0);
      return (true);
   }
   return(false);
} 

bool NewBar4(int period){
   static datetime lastbar;
   if(lastbar!=iTime(_Symbol_,period,0)){
      lastbar=iTime(_Symbol_,period,0);
      return (true);
   }
   return(false);
}

bool IsNewGMTDay() {
   static int Today=-1;
   if(Today!=TimeDayOfWeek(timeGMT)){ 
      Today=TimeDayOfWeek(timeGMT);
      return(true);  
   }
   return(false);
}

bool IsNewWeek() {
   static datetime lastbar;
   if(lastbar!=iTime(_Symbol_,PERIOD_W1,0)){
      lastbar=iTime(_Symbol_,PERIOD_W1,0);
      return (true);
   }
   return(false);
}

bool IsNewWeek_gmt() {
   static datetime lastbar;
   if(lastbar!=iTime(_Symbol_,PERIOD_W1,0)){
      lastbar=iTime(_Symbol_,PERIOD_W1,0);
      return (true);
   }
   return(false);
}   


bool IsNewMonth() {
   static datetime lastbar;
   if(lastbar!=iTime(_Symbol_,PERIOD_MN1,0)) {
      lastbar=iTime(_Symbol_,PERIOD_MN1,0);
      return (true);
   }
   return(false);
}

bool IsNewGMTDayLog() {
   static int Today=-1;
   if(Today!=TimeDayOfWeek(timeGMT)){ 
      Today=TimeDayOfWeek(timeGMT);
      return(true);  
   }
   return(false);
}

bool validateItems(string _symb,string _basketid) {
     if(BaseSymbolName(_symb)=="") return(false);
     for (int x=0; x<StringLen(_basketid)-1; x++) {
            string t = StringSubstr(_basketid,x,1);
            StringToUpper(t);
            if(StringFind("ABCDEFGHIJKLMNOPQRSTUVWXYZ",t)>-1) return(false);
     } 
     return(true);
}

string buildTradeComment(int z, string _xm7tradecomment, string _basketid, string _rezult) {      
       
       string _tradecomment=_xm7tradecomment+"_"+_xm7_magicnumber_str+"_"+_basketid+"_";
       string zString=(z<10?"0"+IntegerToString(z):IntegerToString(z));
       
       _rezult=StringTrimLeft(StringTrimRight(_rezult));
            
      if(_rezult!="" || StringLen(_rezult)>0)
         _tradecomment+=_rezult+"_"+zString;
         
      _tradecomment+=zString;
      
      int xm7_cmn_len=StringLen(_xm7tradecomment);
      
      //max comment length=31, so truncate
      while(StringLen(_tradecomment)>31) {  //If exceeds max 31 then shrink _xm7_TradeComment until total length<31
             xm7_cmn_len--;
             _xm7_TradeComment=StringSubstr(_xm7tradecomment,0,xm7_cmn_len);
             _tradecomment=_xm7tradecomment+"_"+_xm7_magicnumber_str+"_"+_basketid+"_"+zString;
             if(_rezult!="" || StringLen(_rezult)>0)
                  _tradecomment=_xm7tradecomment+"_"+_xm7_magicnumber_str+"_"+_basketid+"_"+_rezult+"_"+zString;
             if(xm7_cmn_len==1) {  _tradecomment=StringSubstr(_tradecomment,0,31); break; }    
      }
      return(_tradecomment);
} 

void combineBuySellCounts(){
           //Combine all sells with sells and buy with buys per pair
           int buysell_count=0;
           for(int x=0; x<ArraySize(_pairs); x++){

                if(StringLen(_pairs[x].symbol)==0) continue; 
                  
                    buysell_count=0; 
                    for(int y=0; y<ArraySize(_pairs); y++){      
                          if(StringLen(_pairs[y].symbol)==0) continue;
                          if(x==y) { buysell_count=_pairs[x].optype; continue; }             
                          if(_pairs[x].symbol==_pairs[y].symbol){     
                                if(_pairs[y].optype==OP_BUY) buysell_count++;       
                                if(_pairs[y].optype==OP_SELL) buysell_count--; 
                                _pairs[y].symbol="";
                                _pairs[x].buysellcnt=buysell_count;
                          }
                    } 
           } 
}


void GetPairs() {
   int t1=ObjectsTotal(_xm7_ind_chartid)-1,cnt=0,x,buysell_count; 
   string id_string="",objString, BaseSymbol="",basketId="";
   string local_symbol="",filter_list="",cmd_str="",IndicatorUsed;
   int optype=-1;
  
   if(ArraySize(_pairs)>0) ArrayFree(_pairs);
   
//==For backtest:  
   if(IsTesting()) {
      local_symbol=Symbol();  buysell_count=0; basketId="1";
      optype=randomOP();

      if(ReverseSignals==ReverseAll)
          optype=(optype==OP_BUY?OP_SELL:(optype==OP_SELL?OP_BUY:-1));

      buysell_count=(optype==OP_BUY?1:-1);
      
      if(optype==-1) return;
      
      ArrayResize(_pairs,cnt+1);
      _pairs[cnt].symbol=local_symbol; 
      _pairs[cnt].basketid=basketId;                
      _pairs[cnt].optype=optype;
      _pairs[cnt].buysellcnt=buysell_count;  
   }
//==End backtest
  
   IndicatorUsed="";
   
   if(!IsTesting()){
   
         buysell_count=0;

         while(t1>-1) {
            if ((StringFind(ObjectName(_xm7_ind_chartid,t1),"CCF_diff")>-1 && StringFind(ObjectName(_xm7_ind_chartid,t1),"suggest")>-1) || 
                 StringFind(ObjectName(_xm7_ind_chartid,t1),"CMSM_Label_Suggestions")>-1 || StringFind(ObjectName(_xm7_ind_chartid,t1),"Signals_TRADE")>-1){
                
                id_string="_";
                if (StringFind(ObjectName(_xm7_ind_chartid,t1),"CCF_diff")>-1 && 
                    StringFind(ObjectName(_xm7_ind_chartid,t1),"suggest")>-1) id_string="CCF_diff";

                if(StringLen(IndicatorUsed)==0)
                     if(StringFind(ObjectName(_xm7_ind_chartid,t1),"CMSM")>-1) IndicatorUsed="CMSM";
                
                BaseSymbol=""; local_symbol=""; optype=-1; basketId="";
                
                BaseSymbol=BaseSymbolName(ObjectName(_xm7_ind_chartid,t1)); 
                if(BaseSymbol=="") { t1--; continue; }
                
                if(StringLen(disallowPairsCurrencies)>0)
                  if(excludeItems(BaseSymbol,disallowPairsCurrencies)) { t1--; continue; }
                  
                local_symbol=Prefix+BaseSymbol+Suffix; 
                local_symbol=StringTrimLeft(StringTrimRight(local_symbol)); //just in case there are blanks spaces
                    
                objString=ObjectGetString(_xm7_ind_chartid,ObjectName(_xm7_ind_chartid,t1),OBJPROP_TEXT);
                StringToLower(objString);
                optype=(StringFind(objString,"buy")>-1?OP_BUY:(StringFind(objString,"sell")>-1?OP_SELL:-1));
                if(optype==-1)  { t1--; continue; }

                SymbolSelect(local_symbol,true);   //make symbol attive in data window       
                /*if(MarketInfo(local_symbol,MODE_BID)==0) {
                         local_symbol=CycleThruSuffixes(BaseSymbol,Prefix,Suffix);
                         if(local_symbol=="") { t1--; continue; }
                         SymbolSelect(local_symbol,true);  //make symbol attive in data window       
                }*/
                      
                refreshRates();
                
                if(MarketInfo(local_symbol,MODE_BID)==0) { 
                     if(debugTrades) Print(__FUNCTION__+"(): Symbol ",local_symbol," was not found on broker's list, magicNumber: ",(string)MagicNumber);
                      t1--; continue; 
                }

                //Get the indicator ID that this pair is associated to
                int pos=StringFind(ObjectName(_xm7_ind_chartid,t1),id_string);  
                if(pos>3) { t1--; continue; }         
                basketId=StringSubstr(ObjectName(_xm7_ind_chartid,t1),0,pos);  
                if(StringLen(basketId)>3) basketId=StringSubstr(basketId,0,3);
                    
               if(ReverseSignals==ReverseAll)
                  optype=(optype==OP_BUY?OP_SELL:(optype==OP_SELL?OP_BUY:-1));

               buysell_count=(optype==OP_BUY?1:-1);
               
               if(optype==-1) return;
              
               double strength=0;
               //Only do this when using CMSM indicator
               if(SortByStrength && IndicatorUsed=="CMSM")
                  strength=(double)((int)basketId*10000+ObjectGetInteger(_xm7_ind_chartid,ObjectName(_xm7_ind_chartid,t1),OBJPROP_YDISTANCE));
                    
               ArrayResize(_pairs,cnt+1);
               _pairs[cnt].symbol=local_symbol; 
               _pairs[cnt].basketid=basketId;                
               _pairs[cnt].optype=optype;
               _pairs[cnt].buysellcnt=buysell_count;
               _pairs[cnt].strength=strength; 
               cnt++;                 
            }      
            t1--;
         }//End of _pairs development 
         
         double sortItem[];
         if(IndicatorUsed=="CMSM") { //Only do this when using CMSM indicator
               if(SortByStrength && ArraySize(_pairs)>0) { 
                  ArrayResize(sortItem,ArraySize(_pairs));
                  for(x=0; x<ArraySize(_pairs); x++) sortItem[x]=_pairs[x].strength;
                  sort_multiDimen_array(sortItem,_pairs);
               }
         }          
              
    }//if(!IsTesting())
    
   if(SortByStrength && IndicatorUsed!="CMSM") {
       Print(__FUNCTION__,"()  line: ",__LINE__,"  You selected SortByStrength=true. This input only works when using the CMSM indicator");
       Print(__FUNCTION__,"()  line: ",__LINE__,"  The EA will continue but SortByStrength is now set to false.");
       SortByStrength=false; 
   } 

   if(debugInfo) {
      Print(" ==== ",__FUNCTION__,"(): Pairs detected from indicator list(",(string)MagicNumber,"): ======");
      if(_OrdersTotal()>0) Print(" ==== (looking for new trades to add to basket) ====");   
      for(x=0; x<ArraySize(_pairs); x++){
            if((int)_pairs[x].optype==OP_BUY) cmd_str="Buy";
            if((int)_pairs[x].optype==OP_SELL) cmd_str="Sell";
            if(_pairs[x].symbol!="") { Print(x,"  ",_pairs[x].symbol+" ",cmd_str,"   ID: ",_pairs[x].basketid,"  strength_pos: ",(string)_pairs[x].strength); }
      }
      Print("_pairs size: ",ArraySize(_pairs));
      if(_OrdersTotal()>0) Print(" ==== (looking for new trades to add to basket) ====");
      Print(" ==== ",__FUNCTION__,"(): Pairs detected from indicator list(",(string)MagicNumber,"): ======");       
   }  
     
}

void OpenVirtualTrades() {
  string symb,cmd_str,basket_id;
  int optype=-1,buysell_cnt,strength;
  double vprice=0, vprofit=0, currentPrice=0;
  dynArray _pairs_[],_vtemp[];  
  
  GetPairs();  

  if(ArraySize(_pairs)==0) return;  
  
  if(applyRealtoVB)
      if(!ProcessOtherFilterConditions(_pairs)) return; // process pairs[]  
  
  if(ArraySize(_virtualOrders)>0) // backup any incoming virtOrders to _virtOrders (keep vprice same for same vorders)
         ArrayCopyDynamic(_vtemp,_virtualOrders);          

  ArrayFree(_virtualOrders); 
  ArrayResize(_virtualOrders,ArraySize(_pairs));
 
  int vcount=0;
  for(int x=0; x<ArraySize(_pairs); x++){
       
       if(StringLen(_pairs[x].symbol)==0) continue;
         
       symb=_pairs[x].symbol; //symbol
       optype=(int)_pairs[x].optype; //optype
       basket_id=_pairs[x].basketid; // basket_id
       buysell_cnt=(int)_pairs[x].buysellcnt;
       strength=(int)_pairs[x].strength;
       
       refreshRates();
       
       if(optype==OP_BUY) { cmd_str="Buy"; vprice=MarketInfo(symb,MODE_ASK); }
       if(optype==OP_SELL) { cmd_str="Sell"; vprice=MarketInfo(symb,MODE_BID); }
       
       double digitz=MarketInfo(symb,MODE_DIGITS);
       double pntz=MarketInfo(symb,MODE_POINT);
       if(digitz==3 || digitz==5) pntz=pntz*10;
       if(optype==OP_BUY) currentPrice=MarketInfo(symb,MODE_BID);
       if(optype==OP_SELL) currentPrice=MarketInfo(symb,MODE_ASK);      
       
       if(optype==OP_BUY) vprofit=(currentPrice-vprice)/pntz;
       if(optype==OP_SELL) vprofit=(vprice-currentPrice)/pntz;
       vprofit=NormalizeDouble(vprofit,1); 
       
       _virtualOrders[vcount].symbol=symb;
       _virtualOrders[vcount].optype=optype;
       _virtualOrders[vcount].basketid=basket_id;
       _virtualOrders[vcount].buysellcnt=buysell_cnt;
       _virtualOrders[vcount].strength=strength;   
       _virtualOrders[vcount].vprice=vprice;
       _virtualOrders[vcount].vprofit=vprofit; 
       vcount++;                  
  } // end of _virtualBasket development

    if(MaxVirtTradesAllowed>0)
          if(ArraySize(_virtualOrders)>MaxVirtTradesAllowed) 
               ArrayResize(_virtualOrders,MaxVirtTradesAllowed);
    
    //Preserv previous vprice for pairs that are still in vb
    if(applyRealtoVB && ArraySize(_vtemp)>0) 
         for(int x=0; x<ArraySize(_virtualOrders); x++)
            for(int y=0; y<ArraySize(_vtemp); y++)
                  if(_virtualOrders[x].symbol==_vtemp[y].symbol &&  _virtualOrders[x].optype==_vtemp[y].optype && //optype
                     _virtualOrders[x].basketid==_vtemp[y].basketid) { 
                               _virtualOrders[x].buysellcnt=_vtemp[y].buysellcnt; //buysell_cnt; 
                               _virtualOrders[x].vprice=_vtemp[y].vprice; //vprice;
                               _virtualOrders[x].vprofit=_vtemp[y].vprofit; //profit;
                               break;
                  }
   
  if(debugInfo){
       Print(" ==== ",__FUNCTION__,"() virtual trade basket (",(string)MagicNumber,") ======");
       for(int x=0; x<ArraySize(_virtualOrders); x++) {
            if((int)_virtualOrders[x].optype==OP_BUY) cmd_str="Buy";
            if((int)_virtualOrders[x].optype==OP_SELL) cmd_str="Sell";       
            Print(x,"  ",cmd_str+" "+_virtualOrders[x].symbol+" profit: "+DoubleToStr(_virtualOrders[x].vprofit,1)); }
            Print("_virtualOrders size: ",ArraySize(_virtualOrders));
       Print(" ==== ",__FUNCTION__,"()  virtual trade basket (",(string)MagicNumber,") ======");
 }     

}

void OpenTrades() {  
  string symb,basketid,tradecomment,result[],rezult,cmd_str;
  int optype=-1,ret,buysell_count,n; //,digitz;  //, summedlotz;
  double price=0, sl=0, tp=0, symbpoint, lotz, lotz_;
  double Balance_,AccountBalance_,balRatio; //factor
  dynArray _temp[1];
  bool flag;

  AccountBalance_=AccountBalance();
  if(AccountCredit()>0) AccountBalance_=AccountBalance()+AccountCredit();
  
  if(!UseVirtualBasket) {   
      if(ArraySize(_pairs)==0) return; 
      if(!ProcessOtherFilterConditions(_pairs)) return;     
  } else if(UseVirtualBasket && (ArraySize(_virtualOrders)>0 && _xm7_rBasketOpenHour==0)) {
     ArrayFree(_pairs);
     ArrayCopyDynamic(_pairs,_virtualOrders); //_virtualOrders have already been thru ProcessOtherFilterConditions()    
   }

  //test for _virtualOrders[] profit>=0 into real basket, _xm7_rBasketOpenHour is not opened a realBasket, _pairs is already a copy of _virtOrders
  if(UseVirtualBasket && OnlyPositivetvTradesToRBasket && ((ArraySize(_pairs)>0 && _xm7_rBasketOpenHour==0) || continueProcessingVB)) {   
         if(minPipsToRBasket<0) minPipsToRBasket=0;
         
         n=1;
         for(int y=0; y<ArraySize(_pairs); y++)  {
              flag=false;
              if(_pairs[y].vprofit<minPipsToRBasket) flag=true; //true means don't keep it
         
               if(!flag) {
                  _temp[n-1].symbol=_pairs[y].symbol;
                  _temp[n-1].basketid=_pairs[y].basketid;
                  _temp[n-1].optype=_pairs[y].optype;
                  _temp[n-1].buysellcnt=_pairs[y].buysellcnt;
                  _temp[n-1].strength=_pairs[y].strength;
                  _temp[n-1].vprice=_pairs[y].vprice;
                  _temp[n-1].vprofit=_pairs[y].vprofit;
                  n++;
                  ArrayResize(_temp,n);
               }         
         }
         
         ArrayResize(_temp,n-1);
         if(ArraySize(_temp)>0) {
              ArrayCopyDynamic(_pairs,_temp); //place results in _pairs for processing to real basket 
         } else {
              ArrayFree(_pairs);  // No trades passed cause none had any profit.
              return;
         }     
                     
  }             

 
   if(debugTrades || debugFilter) {
       Print(" ==== ",__FUNCTION__,"() Trades processed for trading (",(string)MagicNumber,"): ======");
       for(int x=0; x<ArraySize(_pairs); x++) {
            if(StringLen(_pairs[x].symbol)==0) continue;
            if((int)_pairs[x].optype==OP_BUY) cmd_str="Buy";
            if((int)_pairs[x].optype==OP_SELL) cmd_str="Sell"; 
            Print(__FUNCTION__,"()   ",cmd_str+"  ",_pairs[x].symbol,"  basket_id: ",_pairs[x].basketid); }
       Print(" ==== ",__FUNCTION__,"() Trades processed for trading ======");
    }

  if(MaxTradesAllowed>0)
      if(ArraySize(_pairs)>MaxTradesAllowed)
         ArrayResize(_pairs,MaxTradesAllowed);
     
  for(int x=0; x<ArraySize(_pairs); x++){
   
      price=0; sl=0; tp=0; 
      rezult=""; cmd_str=""; 
      
      symb=_pairs[x].symbol;
      optype=(int)_pairs[x].optype;
      basketid=_pairs[x].basketid;
      buysell_count=(int)_pairs[x].buysellcnt;            
      
      if(StringLen(symb)==0) continue;

      if(!validateItems(symb,basketid)) continue;
                  
      if(B1Done) {   
           
           bool AllowNewTrade=false;

           if(AllowNewTradesToBasket || discreteOpenHours) //AllowNewTradesToBasket: Allow new trades but not duplications
               if(AllowNewTradeDuplicates) {  
                  AllowNewTrade=true;
               } else {
                  if(DoesSymbolHaveOpenTrade(symb,optype,MagicNumber,_xm7_magicnumber_str+"_"+basketid,rezult)) continue;               
               }
                      
           if(!AllowHedgeRealTrades) 
                if(ChkHedge(symb,optype,MagicNumber,_xm7_magicnumber_str+"_"+basketid,rezult)) continue;  

           if(FlipSignalIfTradeOpposite)
                if(FlipExistingTrade(symb,optype,MagicNumber,_xm7_magicnumber_str+"_"+basketid,(x+1),_xm7_TradeComment,basketid)) continue; 
                                      
           if(!AllowNewTradesToBasket && discreteOpenHours) AllowNewTrade=true;
               
           if(!AllowNewTradesToBasket || !AllowNewTrade) continue; //do not continue if user set this inputs with these values 
    
      }
            
      tradecomment=buildTradeComment((x+1),_xm7_TradeComment,basketid,rezult);        

      refreshRates();
      
      if(optype==OP_BUY) { 
            cmd_str="Buy"; price=NormalizeDouble(MarketInfo(symb,MODE_ASK),Digits); 
            symbpoint=MarketInfo(symb,MODE_POINT);
            if(MarketInfo(symb,MODE_DIGITS)==3 || MarketInfo(symb,MODE_DIGITS)==5)
               symbpoint=symbpoint*10;
            if(_individualTrades_take_profit>0 || _individualTrades_stop_profit>0) {
               if(_individualTrades_stop_profit>0) sl=price-_individualTrades_stop_profit*symbpoint;
               if(_individualTrades_take_profit>0) tp=price+_individualTrades_take_profit*symbpoint;
            }           
        }
        
       if(optype==OP_SELL) { 
            cmd_str="Sell"; price=NormalizeDouble(MarketInfo(symb,MODE_BID),Digits);
            symbpoint=MarketInfo(symb,MODE_POINT);
            if(MarketInfo(symb,MODE_DIGITS)==3 || MarketInfo(symb,MODE_DIGITS)==5)
               symbpoint=symbpoint*10;
            if(_individualTrades_take_profit>0 || _individualTrades_stop_profit>0) {
               if(price>0 && _individualTrades_stop_profit>0) sl=price+_individualTrades_stop_profit*symbpoint;
               if(price>0 && _individualTrades_take_profit>0) tp=price-_individualTrades_take_profit*symbpoint;
            }       
       }

       if(price>0 && optype!=-1) {  
             lotz=FixedLotSize; // default
             
             switch(LotSizing){
             
                case(Fixed): break;
         
                case(LotsPerBalance):  
                        StringToArray(Lots_Per_Balance,"/",result); 
                        if(ArraySize(result)!=0) {
                            lotz_=StringToDouble(result[0]);
                            Balance_=StringToDouble(result[1]);
                            balRatio=AccountBalance_/Balance_;                      
                            lotz=MathFloor((balRatio*lotz_)/MarketInfo(symb,MODE_LOTSTEP))*MarketInfo(symb,MODE_LOTSTEP);    
                        }        
                break;               
                       
             }
      
             lotz=correctLots(symb,lotz);  
             
             lotz=MathAbs(buysell_count*lotz);
              
             if(lotz==0) continue;  // No trade cause symbol was already processed 

             if(debugTrades) 
                  Print(__FUNCTION__+"(): ",TimeToStr(timeGMT)," MagicNumber: ",(string)MagicNumber,"   x:",x,"  open trade: ",symb,"   entry  ",price,"  lot: ",lotz,"  sl: ",sl,"  tp: ",tp,"  buysell_count: ",(string)buysell_count);
            
            if(!CheckMargin(symb,lotz,optype)) return;  // No more trading margin level too low
            
            int cnt=0;
            while(IsTradeContextBusy()) { Sleep(50); if(cnt>10) break; cnt++; };
            
            ret=SendTrade(optype,symb,lotz,price,sl,tp,tradecomment);            
            
            if(ret==0) {
               Print("EA attempted to trade symbol ",symb," but failed, error(0) was returned be metatrader server");
               Print("If you see 'Common Error' that means that there was an issue with communications to the Metatrader server."+
                     "try these: reload EA, reload Metatrader, or refresh server list and relogin into Metatrader account.");
               Print("EA found error(0). Trading has stopped.");
               if(UseVirtualBasket) ArrayFree(_virtualOrders);
               ArrayFree(_pairs);
               return;      
            }
      
            if(ret==132) { //Market Closed
               MessageBox("No Trades, Market is Closed",DisplayTitle,MB_ICONINFORMATION);
               if(UseVirtualBasket) ArrayFree(_virtualOrders);
               ArrayFree(_pairs);
               return;   
            }
            
            if(ret==133 || ret==2114 || ret==4106 || ret==136 || ret==138 || ret==129) { 
                  switch(ret){
                     case(133): //err 133 Trade Disabled, 
                        Print("The EA found that this pair: ",symb," has it's Trading Disabled.  Check with your broker. Pair was skipped.");
                     break;
                         
                     case(2114): //err 133 Trade Disabled, 
                        Print("The EA found that this pair: ",symb," has it's Trading Disabled.  Check with your broker. Pair was skipped.");                                   
      
                     case(4106):  //err 4106 Unknown Symbol,
                        Print("The EA cound not find pair: ",symb," in broker market list. Check with your broker. Pair was skipped.");                  
                     break;
                     
                     case(136):  //err 136 off quotes 
                        Print("The EA cound not open trade fir pair: ",symb," quotes were off or requoted too much. Check with your broker. Pair was skipped.");            
                     break;
      
                     case(138):  //err 138 requotes 
                        Print("The EA cound not open trade fir pair: ",symb," quotes were off or requoted too much. Check with your broker. Pair was skipped.");            
                     break;
                                      
                     case(129):   // err 129 INVALID PRICE   
                        Print("The EA cound open ttrade for pair: ",symb," open price was invalid. Check code or broker. Pair was skipped.");                  
                     break;               
                  }
                  
                  continue; 
            } 

            if(ret==ERR_NOT_ENOUGH_MONEY) {  //not enough money
               if(UseVirtualBasket) ArrayFree(_virtualOrders);
               ArrayFree(_pairs);
               if(_OrdersTotal()==0) Print("Not Enough money to open lotsize: ",(string)lotz);
               if(_OrdersTotal()>0) Print("Not Enough money to open another trade.  Ea will continue with already opened trades.");
               return; 
            }
       }
       Sleep(5);  
  }
   
   ArrayFree(_pairs);
}


void MonitorOpenVirtualTrades() {
  string symb,op;
  int optype=-1,n;
  double price=0, profit=0, currentPrice=0;
  virtual_profit=0;

  if(applyRealtoVB || continueProcessingVB) OpenVirtualTrades(); //update the _virtualOrders array
 
  if(ArraySize(_virtualOrders)==0) return;
    
  virtual_trades_list=""; 
  n=0;
    
  for(int x=0; x<ArraySize(_virtualOrders); x++){
       symb=StringTrimRight(StringTrimLeft(_virtualOrders[x].symbol)); 

       if(StringLen(symb)==0) continue;

       optype=(int)_virtualOrders[x].optype; 
       price=_virtualOrders[x].vprice;
       
       refreshRates();
             
       double digitz=MarketInfo(symb,MODE_DIGITS);
       double pntz=MarketInfo(symb,MODE_POINT);
       if(digitz==3 || digitz==5) pntz=pntz*10; 
       
       if(optype==OP_BUY) currentPrice=MarketInfo(symb,MODE_BID);
       if(optype==OP_SELL) currentPrice=MarketInfo(symb,MODE_ASK);
       
       if(optype==OP_BUY) profit=(currentPrice-price)/pntz;
       if(optype==OP_SELL) profit=(price-currentPrice)/pntz;
       profit=NormalizeDouble(profit,1);  
       
       _virtualOrders[x].vprofit=profit;    
       virtual_profit+=profit; 
      
       if(optype==OP_BUY) op="Buy";
       if(optype==OP_SELL) op="Sell";
       
       if(ArraySize(_virtualOrders)<=30){
            if(MathMod((n+1),2)==0) { 
               virtual_trades_list=virtual_trades_list+op+" "+symb+"  "+DoubleToStr(profit,1)+" pips,";
            } else {
               virtual_trades_list=virtual_trades_list+op+" "+symb+"  "+DoubleToStr(profit,1)+" pips   ";
            }             
       } else {
            virtual_trades_list="Too Many Pairs to Display,Max vTrades to display 30, Total number of vTrades: "+(string)ArraySize(_virtualOrders); 
       }
       
       n++;
  } 

  if(StringFind(virtual_trades_list,",",StringLen(virtual_trades_list)-1)>-1)
         virtual_trades_list=StringSubstr(virtual_trades_list,0,StringLen(virtual_trades_list)-1);
  
  virtual_trades_list=StringTrimLeft(StringTrimRight(virtual_trades_list));
  
  datetime dTime=TimeGMT();
  double dbTime=(double)dTime;
  if(virtual_profit>vHighest_pips) { vHighest_pips=NormalizeDouble(virtual_profit,1);  GlobalVariableSet("xm7_vHighPip_"+_xm7_magicnumber_str,vHighest_pips); vMaxTime=TimeToStr(dTime); GlobalVariableSet("xm7_maxVtime_"+_xm7_magicnumber_str,dbTime);   }
  if(virtual_profit<vLowest_Pips) { vLowest_Pips=NormalizeDouble(virtual_profit,1);  GlobalVariableSet("xm7_vLowPip_"+_xm7_magicnumber_str,vLowest_Pips); vMinTime=TimeToStr(dTime); GlobalVariableSet("xm7_minVtime_"+_xm7_magicnumber_str,dbTime);   }
 
}

void backupVirtualArray(string _file) {

      int      FLAGS   = FILE_WRITE|FILE_TXT|FILE_ANSI;  // With only FILE_WRITE file is recreated each time, otherwise FILE_READ|FILE_WRITE recreates or uses existing file
      int   handle   = FileOpen(_file, FLAGS,","), n=0;; 

      if(handle != INVALID_HANDLE){ 
         
         FileWrite(handle,TimeToStr(_xm7_vBasketTriggeredHour),
                          vMaxTime,DoubleToStr(vHighest_pips,1),
                          vMinTime,DoubleToStr(vLowest_Pips,1),
                          DoubleToStr(virtual_profit,1),(string)_virtualbasketclosedTime);
             
         for(int x=0; x<ArraySize(_virtualOrders); x++) {          
           if(StringTrimLeft(StringTrimRight(_virtualOrders[x].symbol))=="") continue;

            refreshRates();
            int digitz=(int)MarketInfo(_virtualOrders[x].symbol,MODE_DIGITS);  
            
            FileWrite(handle,_virtualOrders[x].symbol, // symbol
                             (string)_virtualOrders[x].optype, //optype
                             DoubleToStr(_virtualOrders[x].vprice,digitz), //vprice
                             DoubleToStr(_virtualOrders[x].vprofit,1)); //vprofit
         }               

         FileClose(handle);
      } else {
         Print("error backing up virtualbasket array()");
      }
}

void recoverVirtualArray(string _file, dynArray& _virtOrders[]) {
      
      string result[],data[];
            
      ReadFileIntoArray(_file,result);

      if(ArraySize(result)==0) return;

      ArrayResize(_virtOrders,ArraySize(result));
      
      //GET data from virtualorder file into an ARRAY, this is done BEFORE the file might be deleted
      int n=0,tmpcnt=0;
      for (int x=0; x<ArraySize(result); x++) {
       
      ArrayFree(data); 
      StringToArray(result[x],",",data); 
                 
      if(x==0) {
         
            _xm7_vBasketTriggeredHour=StringToTime(data[0]); GlobalVariableSet("xm7_vBasketTriggerHour_"+_xm7_magicnumber_str,(double)_xm7_vBasketTriggeredHour);
            
            if(data[1]!=""){
               vMaxTime=data[1]; GlobalVariableSet("xm7_maxVtime_"+_xm7_magicnumber_str,(double)StringToTime(data[1]));
               vHighest_pips=(double)data[2]; GlobalVariableSet("xm7_vHighPip_"+_xm7_magicnumber_str,(double)data[2]); 
            }
            
            if(data[3]!=""){
               vMinTime=data[3]; GlobalVariableSet("xm7_minVtime_"+_xm7_magicnumber_str,(double)StringToTime(data[3]));
               vLowest_Pips=(double)data[4]; GlobalVariableSet("xm7_vLowPip_"+_xm7_magicnumber_str,(double)data[4]);
            }
            
            virtual_profit=(double)data[5];
            
            _virtualbasketclosedTime=StringToTime(data[6]);
             
      }
    
      if(x>=1){
            
            _virtOrders[x].symbol=data[0]; // symbol
            _virtOrders[x].optype=(int)data[1]; // optype
            _virtOrders[x].vprice=(double)data[2]; // vprice
            _virtOrders[x].vprofit=(double)data[3]; // vprofit
            
            if((int)data[1]==OP_BUY) data[1]="Buy";
            if((int)data[1]==OP_SELL) data[1]="Sell";            
            
             if(ArraySize(_virtualOrders)<=30){
                  if(MathMod((n+1),2)==0) { 
                     virtual_trades_list=virtual_trades_list+data[1]+" "+data[0]+"  "+data[3]+" pips,";
                  } else {
                     virtual_trades_list=virtual_trades_list+data[1]+" "+data[0]+"  "+data[3]+" pips   ";
                  }             
             } else {
                  virtual_trades_list="Too Many Pairs to Display,Max vTrades to display 30, Total number of vTrades: "+(string)ArraySize(_virtualOrders); 
             }
             n++;            
         }     
      
      }
      
} 

int countLinesInFile(string _file) {
      int nLines = 0,
          handle = FileOpen(_file, FILE_CSV|FILE_READ, '~');
      if(handle < 1) return(-1);
      while(true){
         string line = FileReadString(handle);
         if(line == "") break; // EOF
         nLines++;
      }
      FileClose(handle);
      return(nLines);
}

void writeArrayIntoFile(string _filename, string& result[]) {
      int      FLAGS   = FILE_WRITE|FILE_TXT|FILE_ANSI;  // With only FILE_WRITE file is recreated each time, otherwise FILE_READ|FILE_WRITE recreates or uses existing file
      int   handle   = FileOpen(_filename, FLAGS,","); 
      
      if(handle != INVALID_HANDLE){ 
         for(int x=0; x<ArraySize(result); x++)            
            FileWrite(handle,result[x]); 
         
         FileClose(handle);
      } else {
         Print("error writing array into virtFile");
      }
}

void ReadFileIntoArray(string filename, string& result[], char fieldSeparator='\t',bool skipEmptyLines=true) {

   int hFile, hFileBin=0;                       


   hFile= FileOpen(filename,FILE_CSV|FILE_READ,fieldSeparator);
   if (hFile < 0) {
      Print("Can't open file");
      ArrayFree(result);
      return;
   }
   
   // read file line by line
   bool newLine=true, blankLine=false, lineEnd=true, wasSeparator;
   string line, value, lines[]; ArrayResize(lines, 0);   // lines[]: tmp. storage for readed lines
   int i=0, len, fPointer=0;   // line counter and length of read string  
         
   while (!FileIsEnding(hFile)) {

      newLine = false;
      if (lineEnd) {                    // If the last loop encountered end of line
         newLine   = true;              // we reset all flags to start of new line.
         blankLine = false;
         lineEnd   = false;
         fPointer  = (int)FileTell(hFile);   // always points to start of current line
      }

      // read line
      value = FileReadString(hFile);

      // check for line or file end (whatever comes first)
      if (FileIsLineEnding(hFile) || FileIsEnding(hFile)) {
         lineEnd  = true;
         if (newLine) {
            if (StringLen(value) == 0) {
               if (FileIsEnding(hFile)) break;                             // start_of_line + empty + end_of_file => in fact nothing -> break 
               blankLine = true;                                           // start_of_line + empty + end_of_line => blank line
            }
         }
      }

      // skip blank lines
      if (blankLine) /*&&*/ if (skipEmptyLines) continue;
   
      // store read value in new line or update previous line
      if (newLine) {
         i++;
         ArrayResize(lines, i);
         lines[i-1] = value;
      }  else {
         // FileReadString() reads max. 4095 chars: check last char of long lines for separator
         len = StringLen(lines[i-1]);
         if (len < 4095) {
            wasSeparator = true;
         }  else {
            // long line: re-open the same file in binary mode and check the character where FileReadString() stopped for separator
            if (hFileBin == 0) {
               hFileBin = FileOpen(filename, FILE_BIN|FILE_READ);
               if (hFileBin < 0) {
                  FileClose(hFile);
                  ArrayFree(result);
                  return;
               }
            }
            if (!FileSeek(hFileBin, fPointer+len, SEEK_SET)) {
               FileClose(hFile);
               FileClose(hFileBin);
               ArrayFree(result);
               return;
            }
            wasSeparator = (fieldSeparator == FileReadInteger(hFileBin, CHAR_VALUE));
         }

         if (wasSeparator) lines[i-1] = StringConcatenate(lines[i-1], CharToStr(fieldSeparator), value);
         else              lines[i-1] = StringConcatenate(lines[i-1],                            value);
      }  

      // end of file triggered setting of ERR_END_OF_FILE
      int error = GetLastError();
      if (error!=ERR_END_OF_FILE) /*&&*/ if (error!=ERR_NO_ERROR) {
           FileClose(hFile);
           if (hFileBin != 0) FileClose(hFileBin);
           ArrayFree(result);
           return;
       }
   
   }//while()


   // close open files
   FileClose(hFile);
   if (hFileBin != 0) FileClose(hFileBin);

   // copy lines from tmp. storage to result[]
   ArrayResize(result, i);
   if (i > 0) ArrayCopy(result, lines);

   if (ArraySize(lines) > 0) ArrayResize(lines, 0);
  
}    

bool AllowTradesByTime() {    
   double Start_Time=0,End_Time=0;
   string time[],hours[],seperateOpen,txtMonth; //txtHour,txtMin
   string txtMonthDateTime,txtYear,txtDay,result[];
   bool allowTrade=true;
   static bool Today,DayToTrade;
   static int hr=-1,mn=-1,cls_hr=-1,cls_mn=-1;

   if(TradeMode==Monthly) {
         txtMonth= (TimeMonth(timeGMT)<10?"0"+(string)TimeMonth(timeGMT):(string)TimeMonth(timeGMT));
         txtYear=(string)TimeYear(timeGMT);
         txtDay=(GMTDayOfMonth<10?"0"+(string)GMTDayOfMonth:(string)GMTDayOfMonth);
         txtMonthDateTime=txtYear+"."+txtMonth+"."+txtDay;
   }
   
   //User Select Days to trade
   if(TradeMode==Daily) {   
        DayToTrade=true;
        if(StringFind(StringChangeToLowerCase(NoTradeDays),StringChangeToLowerCase(getStringOf(TimeDayOfWeek(timeGMT))))>-1) DayToTrade=false; 
    }

   if(StringFind(StringChangeToLowerCase(GMTOpenHour),"manual")>-1) return(false); 
   
   if(ArraySize(discreteOpen)==0){
         StringToArray(GMTOpenHour,":",hours); hr=(int)hours[0]; mn=(int)hours[1];//Single Open Time 
   }      
 
   if(!Today && ArraySize(discreteOpen)>0)
         GetDiscreteHourMin(hr,mn,cls_hr,cls_mn); // multiple hours

   if(Today && TimeMinute(timeGMT)!=mn) Today=false;    
          
   if(!Today){  
 
         if(TradeMode==Daily) allowTrade=DayToTrade;  
         if(TradeMode==Weekly && TimeDayOfWeek(timeGMT)!=GMTOpenDayofWeek) allowTrade=false;  
         if(TradeMode==Monthly && txtMonthDateTime!=TimeToStr(timeGMT,TIME_DATE)) allowTrade=false;

         if(allowTrade && TimeHour(timeGMT)==hr && TimeMinute(timeGMT)==mn) {    
               if(debugTrades)
                  Print("magic#: ",MagicNumber,":  Today: ",(bool)Today," (false is correct)   DayToTrade: ",(bool)DayToTrade,"  line: ",__LINE__);
               Today=true;
               if(debugTrades)
                  Print("TradeTime started at ( magic#:  ",(string)MagicNumber,"): ",TimeToStr(TimeCurrent(),TIME_MINUTES));                  ;
               return(true);
         } 
     }
   
   if(debugTime && NewBar1(PERIOD_H1)) {
      Print("LocalTime: ",TimeToStr(TimeLocal()),"   BrokerTime: ",TimeToStr(TimeCurrent()),"   timeGMT:: ",TimeToStr(timeGMT));      
      Print("Your Machine is at GMT: ",(string)localGMToffSet,"    MT4 Broker is at GMT: ",(string)brokerGMToffSet);
      Print("Allow Trade for today: ",allowTrade,"     No Trade Days: ", NoTradeDays);
      Print(" ====== ",__FUNCTION__,"()  Magic Number: ",(string)MagicNumber," ====== ");
   }  
   
   return(false);
}

int _OrdersTotal() {
   int _total=0;
   for(int x=0; x<OrdersTotal(); x++) {
      if(!OrderSelect(x,SELECT_BY_POS)) continue; 
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderCloseTime()!=0) continue; //Already closed       
      _total++;
   }
   return(_total);
}

void StringToArray(string str, string separator, string& arryResult[]) {
   ushort u_sep;
   u_sep=StringGetCharacter(separator,0);
   StringSplit(str,u_sep,arryResult);
}

void StringToArrays(string str, string separator, string& _openHour[], string& _closeHour[]) {
   ushort u_sep;
   string temp[];
   int n;

   ArrayFree(_openHour); ArrayFree(_closeHour);
   
   if(StringFind(str,separator)==-1) {
      ArrayResize(temp,1);
      temp[0]=str;
   } else {
      u_sep=StringGetCharacter(separator,0);
      StringSplit(str,u_sep,temp);   
   }   
   
   n=0;
   for(int x=0; x<ArraySize(temp); x++) {
      StringReplace(temp[x]," ","");  
      if(StringFind(temp[x],"-")==5 && StringLen(temp[x])==11) {  //range hours HH:mm-HH2:mm  etc
         ArrayResize(_openHour,n+1);  ArrayResize(_closeHour,n+1);
         _openHour[n]=StringSubstr(temp[x],0,5);//open hour
         _closeHour[n]=StringSubstr(temp[x],6,5);//close hour
         n++;
      } else if(StringLen(temp[x])==5){ //single hour entries HH:mm,HH:mm etc
         ArrayResize(_openHour,n+1);
         _openHour[n]=StringSubstr(temp[x],0,5);//open hour
         n++;      
      }
   
   }
}

//+------------------------------------------------------------------+
int StringFindCount(string str, string str2)
//+------------------------------------------------------------------+
// Returns the number of occurrences of STR2 in STR
// Usage:   int x = StringFindCount("ABCDEFGHIJKABACABB","AB")   returns x = 3
{
  int c = 0;
  for (int i=0; i<StringLen(str); i++)
    if (StringSubstr(str,i,StringLen(str2)) == str2)  c++;
  return(c);
}

int SendTrade(int type,string symbl,double lots,double price,double stop,double take, string cmment) {

   int slippage=10, ticket=0, tries;
   string BaseSymbol="";
   
   refreshRates();
   
   if(MarketInfo(symbl,MODE_DIGITS)==3 || MarketInfo(symbl,MODE_DIGITS)==5) slippage=100;

   color col=Red;
   if(type==OP_BUY || type==OP_BUYSTOP || type==OP_BUYLIMIT) col=Green;
   
   if(!marginTest(symbl,lots)) return(ERR_NOT_ENOUGH_MONEY); //not enuf margin for a new lotsize

    isTradeContextBusy();
    ticket=OrderSend(symbl,type,lots,price,slippage,0,0,cmment,MagicNumber,0,col);                 
    
    if(ticket>-1 && (stop!=0 || take!=0))
        ModifyOrder(ticket,type,stop,take);
      
   //Error trapping for both
   if(ticket<0) {
   
      int err=GetLastError();
 
      //if(err==4106) //Unknown Symbol
      //if(err==133 || err==2114) { //handle trade disabled error
      
      //Try 3 times to see if ERROR can be avoided
      if(err==136 || err==138 || err==129) { // errr 136 off quotes, err 138 requotes, err 129 INVALID PRICE
            tries=0;
            if(err==138) slippage=1000; // Requote
           
            while (tries < 3) {
                 refreshRates();
                 price=MarketInfo(symbl,(type==OP_BUY?MODE_ASK:MODE_BID));
                 isTradeContextBusy();
                 ticket=OrderSend(symbl,type,lots,price,slippage,0,0,cmment,MagicNumber,0,col); 
                 if(ticket!=-1) break;
                 tries++;
                 Sleep(50);
             }
             
             if(ticket>-1)
               if(ModifyOrder(ticket,type,stop,take)) return(ticket);
             
             err=GetLastError();
       }
                 
       string stype;
       if(type == OP_BUY) stype = "OP_BUY";
       if(type == OP_SELL) stype = "OP_SELL";
       if(type == OP_BUYLIMIT) stype = "OP_BUYLIMIT";
       if(type == OP_SELLLIMIT) stype = "OP_SELLLIMIT";
       if(type == OP_BUYSTOP) stype = "OP_BUYSTOP";
       if(type == OP_SELLSTOP) stype = "OP_SELLSTOP";
      
       //This part is reached only if no trade was ever able to be generated 
      string error_str=ErrorDescription(err); StringToUpper(error_str);
      Print(TimeToStr(iTime(symbl,0,0))+": "+symbl," Error in SendTrade(): type = ",type,"  lots = ",lots,"  price = ",price,"   stoploss=",stop,"  takeprofit=",take);
      Print(TimeToStr(iTime(symbl,0,0))+": "+symbl," Error in SendTrade(): order send failed with error(",err,")");
      Print(TimeToStr(iTime(symbl,0,0))+": "+symbl," Error in SendTrade(): error(",err,"): ",error_str);
      return(err);
   }//if (ticket < 0)  

   return(ticket);
}

bool CloseTrade(int ticket,double lotsze, double close_price) {
   bool result=false;
   int tries;
   
   while(IsTradeContextBusy()) Sleep(100);

   tries=0;
   while (tries < 3) {
        result=OrderClose(ticket,lotsze,close_price,1000,SandyBrown);
        if(result) return(true);
        tries++;
        Sleep(300);
   }

   return(result);
}

bool ModifyOrder(int tickt, int ordtype,double stop_loss,double take_profit) {

   int tries;
 
   if(stop_loss==0 && take_profit==0) return(true);   

   if(!OrderSelect(tickt,SELECT_BY_TICKET)) return(false); //Trade does not exist, so no mod needed
   
    while(IsTradeContextBusy()) Sleep(300);
 
    if(OrderModify(tickt, OrderOpenPrice(), stop_loss, take_profit, OrderExpiration(), Aqua)) return(true);
       
   //Got this far, so the order modify failed
   // try 10 times with delay to modify order   
   tries=0;
   while (tries < 3) {
           trd= OrderModify(tickt, OrderOpenPrice(), stop_loss, take_profit, OrderExpiration(), Aqua);
           if(trd) return(true);  //OrderModiy was successful so return
           tries++;
           Sleep(300);
   }
   
   //Error persisted so we log the variables to EXPERTS Tab and very IMPORTANT CLOSE THE TRADE
   string close_message="";
   if(ordtype==OP_BUY) { 
      if (!CloseTrade(OrderTicket(),OrderLots(),Bid)) { 
            close_message="Error in CloseTrade(): EA tried 10 times on ModifyOrder() and failed.  When EA attempted to close OpenTicket there was a problem closing Buy trade @ "+DoubleToStr(Ask,Digits()); 
      }
   }
      
   if(ordtype==OP_SELL) {
       if (!CloseTrade(OrderTicket(),OrderLots(),Ask))  {  
            close_message="Error in CloseTrade(): EA tried 10 times on ModifyOrder() and failed.  When EA attempted to close OpenTicket there was a problem closing Sell trade @ "+DoubleToStr(Bid,Digits()); 
       }
   }    

   int err=GetLastError();
   string error_str=ErrorDescription(err); StringToUpper(error_str);
   if(close_message!="") Print(TimeToStr(Time[0])+": "+Symbol()+" "+close_message);   
   if(close_message!="") Print(TimeToStr(Time[0])+": "+Symbol()+" Error in CloseTrade(), EA was not able to close trade due to ModifyOrder() error");   
   Print(TimeToStr(Time[0])+": "+Symbol()," Error in ModifyOrder(): SL = "+DoubleToStr(stop_loss,Digits())+"    TP = "+DoubleToStr(take_profit,Digits()));
   Print(TimeToStr(Time[0])+": "+Symbol()," Error in ModifyOrder(): SL/TP  order modify failed with error(",err,"): ",error_str);
   return(false);
//   Alert(OrderSymbol(), " SL/TP  order modify failed with error(",err,"): ",ErrorDescription(err));               

}//void ModifyOrder(int ticket, double tp, double sl)  

void ShowDisplay(string pipGain,string currGain_,string daysGain_,string weeksGain_,string monthGain_,string yearGain_,int& mainDisplayLength) {
  
   string pipCount="",SetProfitLocktxt="",LogFiletxt="",units,OpenDayHour,FridayClose;
   string input_dow,gmt_dow,broker_dow,SetEachTrade="";
   string user_closeTime, user_startTime, MaxMinPipGainstxt, minTime="",maxTime="", MarketClosedTxt="";
   string basketTriggeredStatus="";
 
   input_dow=getStringOf(GMTOpenDayofWeek);
   gmt_dow=getStringOf(TimeDayOfWeek(TimeGMT()));
   broker_dow=getStringOf(DayOfWeek());
  
   if(Use_SL_TP_Locks_As==Pips) { units=" pips"; } else { units="%"; }
  
   if(StepFactor!=NoTrail && setStartLocking>0) {
  
         SetProfitLocktxt="ProfitLock set when Gain > "+DoubleToStr(setStartLocking,1)+units+","+
                          "============================,";   
  
         if(StepFactor==TrailStop && _TrailStop>0 && _lock_trig)
                 SetProfitLocktxt="ProfitLock is on and set to: "+DoubleToStr(_basket_stop,1)+units+","+
                                  "Next Lock move when gain >= "+
                                  DoubleToStr(_basket_stop+_TrailStop+setLockDelta,1)+units+","+
                                  "============================,";
         
        /* if(StepFactor==PercentOfProfit && LockPercentLevel>0 && _lock_trig)
                 SetProfitLocktxt="ProfitLock is on and set to: "+DoubleToStr(_basket_stop,1)+units+","+
                                  "Next Lock move when gain >= "+
                                  DoubleToStr((((100/LockPercentLevel)*_basket_stop)+setLockDelta),1)+units+","+
                                  "============================,";*/
         
         if(StepFactor==oneTimeBE  && beLock>0 && _lock_trig)
               SetProfitLocktxt="Manual Lock is locked to: "+DoubleToStr(_basket_oneTimeBE_value,1)+units+","+  
                                "============================,";
   } 
  
   if(_individualTrades_take_profit>0 || _individualTrades_stop_profit>0) 
        SetEachTrade="EA has set TP/SL on each trade,"+
                      "============================,";    
  
   if(Set_TrailingStop_On_EachTrade)
        SetEachTrade="EA is monitoring TrailStop for each trade,"+
                     "============================,";
  
   if((_individualTrades_take_profit>0 || _individualTrades_stop_profit>0) && Set_TrailingStop_On_EachTrade>0)
        SetEachTrade="EA has set TP/SL and is monitoring TrailStop on each trade,"+
                     "============================,";
    
   if(LogData && LogFileName!="")
     LogFiletxt="Basket Max/Min Gain is logged to:,"+
                 LogFileName+","+
                 "File is located in MQL4/Files,"+
                 "============================,";
  
   user_startTime = GMTOpenHour;
   user_closeTime = GMTDailyCloseHour;
  
   //See if user used separate hours
   if(ArraySize(discreteOpen)>0) {
      if(!IsMarketOpen) { user_openTimeStr=discreteOpen[0]; if(ArraySize(discreteClose)>0) user_closeTimeStr=discreteClose[0]; }; //fixes weekend skip
      user_startTime=user_openTimeStr;
      user_closeTime=user_closeTimeStr;
      if(GMTDailyCloseHour!="-")
         if(TimeToStr(timeGMT,TIME_DATE)+" "+GMTDailyCloseHour<=TimeToStr(timeGMT,TIME_DATE)+" "+user_closeTime)
            user_closeTime = TimeToStr(timeGMT,TIME_DATE)+" "+GMTDailyCloseHour; 
         if(user_closeTime=="") user_closeTime = GMTDailyCloseHour;        
   }
    
   if(TradeMode==Monthly) OpenDayHour="Basket Opens on Day "+(string)GMTDayOfMonth+" of Month"+","+
                                      "Basket Opens GMT: "+user_startTime+",";
  
   if(TradeMode==Weekly) OpenDayHour="Basket Opens "+input_dow+" "+user_startTime+" GMT,";
   if(TradeMode==Weekly && ArraySize(discreteClose)>0) OpenDayHour+="Basket Closes "+input_dow+" "+user_closeTime+" GMT,";
   
   if(TradeMode==Daily && GMTDailyCloseHour!="-") OpenDayHour="Basket Opens: "+user_startTime+" Closes: "+user_closeTime+" GMT,";  

   if(TradeMode==Daily && GMTDailyCloseHour=="-") OpenDayHour="Basket Opens: "+user_startTime+" GMT,";    
   
   if((TradeMode==Daily || TradeMode==Weekly) && GMTFridayCloseHour!="-") FridayClose="Basket Will Closed Friday "+GMTFridayCloseHour+",";  
  
  string BasketNumbers="Baskets: "+(string)tradeListOnChart+"   Open Pairs: "+(string)_OrdersTotal()+","; 
  
  string Gains="Gain: "+currGain_+"%("+pipGain+" pips),";
                                                           
  string ATRtxt=""; string RatioTxt="";
  if(Use_ATR) ATRtxt="SL Calculated using each Trade ADR,"; 
  if(Use_ATR && _OrdersTotal()==0) ATRtxt=""; 
   
  if(TP_to_SL_Ratio>0) RatioTxt="TP/SL Ratio: "+(string)TP_to_SL_Ratio;
  if(InvertRatio && TP_to_SL_Ratio>0) RatioTxt="TP/SL Ratio is inverted: "+DoubleToStr((double)(1/TP_to_SL_Ratio),2);
   
  string BasketSLTP="SL: "+DoubleToStr(_basket_stop_profit,1)+units+"  TP: "+DoubleToStr(_basket_take_profit,1)+units+",";
                             
  if(ATRtxt!="" || RatioTxt!="") BasketSLTP=BasketSLTP+ATRtxt+" "+RatioTxt+",";
  
  if (_xm7_maxTime!="") maxTime=" at "+_xm7_maxTime;
  if (_xm7_minTime!="") minTime=" at "+_xm7_minTime;
  
  int resDigits=1;
  if(Use_SL_TP_Locks_As==Percent) resDigits=2;
  MaxMinPipGainstxt="Max "+DoubleToStr(_xm7_max_week_gain,resDigits)+units+"  Min "+DoubleToStr(_xm7_min_week_gain,resDigits)+units+",";
  
  if(ShowTimeMinMax && (_xm7_maxTime!="" || _xm7_minTime!="")) MaxMinPipGainstxt= "Max "+DoubleToStr(_xm7_max_week_gain,1)+units+" "+maxTime+","+
                                                                                  "Min "+DoubleToStr(_xm7_min_week_gain,1)+units+" "+minTime+",";
                                        
  if(!IsMarketOpen) MarketClosedTxt="==============================,"+
                                    " ------ Market is Closed -----,";                                                                              
  
  if(IsTesting()) MarketClosedTxt="==============================,"+
                                  "EA in Tester Mode has limitations:,"+
                                  "1. Only one pair Basket,"+
                                  "2. GMT/Broker Clocks are the same,"+
                                  "3. No buttons (the don't work),"+
                                  "Use this mode to test: vb open/basket trigger,"+
                                  "LockProfit. Trailing Stop. Filters. etc,"; 

  if(_basketisclosed)
         MarketClosedTxt="==============================,"+
                         "Last Basket was closed at "+TimeToStr(_xm7_RealBasketClosedHr,TIME_MINUTES)+" GMT,";     
    

    if(!UseVirtualBasket && rBTrigged_butNoTrades) {
 
          string failedTrigTime=TimeToStr((datetime)GlobalVariableGet("rBTrigged_butNoTrades"+_xm7_magicnumber_str),TIME_MINUTES);
    
         if(cc_filter_fail && TestCandleColors) {
            basketTriggeredStatus = "No realBasket triggerd - Failed at "+failedTrigTime+" GMT, All Trades failed CandleColor filter,"+
                                    "======================,";
         } else if(bbsq_filter_fail && UseBBSqueeze) {
            basketTriggeredStatus = "No realBasket triggerd - Failed at "+failedTrigTime+" GMT, all Trades failed BBSqueeze filter,"+
                                    "======================,";
         } else if(cc_filter_fail && TestCandleColors && bbsq_filter_fail && UseBBSqueeze){
            basketTriggeredStatus = "No realBasket triggerd - Failed at "+failedTrigTime+" GMT,All Trades failed CandelColor or BBSqueeze,"+
                                    "======================,";
         } 

    } 


  string controls_space="";
  if(!IsTesting()) controls_space=",,"; //space for buttons and other stuff
  
  DisplayStatus(20,20,"xm7_Display",DisplayTitle,
                controls_space+
                MarketClosedTxt+
                "==============================,"+
                 BasketNumbers+" "+BasketSLTP+                
                "==============================,"+
                 basketTriggeredStatus+ 
                 Gains+
                "Day: "+daysGain_+"%("+daypips+" pips) Week: "+weeksGain_+"%("+weekspips+" pips),"+
                "Month: "+monthGain_+"%("+monthpips+" pips) Year: "+yearGain_+"%("+yearpips+" pips),"+
                "============================,"+ 
                 MaxMinPipGainstxt+
                "============================,"+
                 SetProfitLocktxt+
                 SetEachTrade+
                 LogFiletxt+         
                 OpenDayHour+ 
                 broker_dow+" "+getTimeMin(TimeCurrent())+" ("+gmt_dow+" "+getTimeMin(timeGMT)+" GMT),"+           
                 FridayClose+               
                "============================,"+                                                                         
                "Account Margin in use: $" +DoubleToStr(AccountMargin(),2)+","+            
                "Account Balance:  $" +DoubleToStr((AccountBalance()+AccountCredit()),2)+","+
                "Account Equity:  $"+DoubleToStr(AccountEquity(),2),                       
                DisplayFontSize,mainDisplayLength);
 
}       

void ShowVirtualBasket(int mainDisplayLength) {
    string virtual_MaxMintxt,virtual_TrigLevelstxt;
    string basketTriggeredStatus="";
    static string OpenHour,separateClose;
    
    OpenHour=GMTOpenHour;
    //See if user used separate hours
    if(ArraySize(discreteOpen)>0) OpenHour=user_openTimeStr;

    if(ArraySize(_virtualOrders)==0 && !GlobalVariableCheck("xm7_vBasketTriggerHour_"+_xm7_magicnumber_str)) 
         basketTriggeredStatus="virtual Basket Opens: "+OpenHour+" GMT,"+
                               "======================,";

    if(showVirtMaxMinPipLimits && ArraySize(_virtualOrders)>0) 
         virtual_MaxMintxt= "Highest Gain: "+DoubleToStr(vHighest_pips,1)+" pips "+vMaxTime+","+
                            "Lowest Gain: "+DoubleToStr(vLowest_Pips,1)+" pips "+vMinTime+","+
                            "======================,";
                                              
    virtual_TrigLevelstxt= "Upper Trigger: "+DoubleToStr(_VirtualUpperTriggerLevel,1)+" pips  "+
                           "Lower Trigger: "+DoubleToStr(_VirtualLowerTriggerLevel,1)+" pips,"+
                           "======================,";

    string negTrig_str; static double negTrig=0;
    if(letEASetNegTrig) {
          if(ArraySize(_virtualOrders)==0) { negTrig_str="TBD when vBasket Opens"; negTrig=0; }
          if(ArraySize(_virtualOrders)>0 && negTrig==0) negTrig=MathAbs(getNegativeTrigger(ArraySize(_virtualOrders)));                        
          if(negTrig>0) negTrig_str=DoubleToStr(negTrig,1)+" pips";
          virtual_TrigLevelstxt= "Upper Trigger: 0 pips  "+
                                 "Lower Trigger: "+negTrig_str+","+
                                 "======================,"; 
    }
                       
    string totals_str= "Total: "+DoubleToStr(virtual_profit,1);
    
    virtual_trades_list=StringTrimLeft(StringTrimRight(virtual_trades_list));
    if(StringLen(virtual_trades_list)!=0) totals_str=totals_str+",";
    
    if(MathAbs(minPipsToRBasket)>0 )  totals_str="Min vb pip profit>"+(string)MathAbs(minPipsToRBasket)+",";                      
    
    if(ArraySize(_virtualOrders)>0 && _xm7_vBasketTriggeredHour!=0) 
            basketTriggeredStatus="virtual Basket Opened at "+TimeToStr(_xm7_vBasketTriggeredHour,TIME_MINUTES)+" GMT,"+
                                  "======================,";
            
    if(_virtualbasketclosedTime!=0 && selectMarkOption!=DoNotCheck && checkProfitStatusMins>0) 
            basketTriggeredStatus="No realBasket triggerd. Reset at: "+TimeToStr(_virtualbasketclosedTime,TIME_MINUTES)+" GMT,"+
                                  "Next virtualBasket Opens at: "+OpenHour+" GMT,"+ 
                                  "======================,";  

    if(vBTrigged_butNoTrades) {
 
          string failedTrigTime=TimeToStr((datetime)GlobalVariableGet("vBtrigged_butNoTrades"+_xm7_magicnumber_str),TIME_MINUTES);
    
         if(cc_filter_fail && TestCandleColors) {
            basketTriggeredStatus = "No realBasket triggerd - Failed at "+failedTrigTime+" GMT, All Trades failed CandleColor filter,"+
                                    "======================,";
         } else if(bbsq_filter_fail && UseBBSqueeze) {
            basketTriggeredStatus = "No realBasket triggerd - Failed at "+failedTrigTime+" GMT, all Trades failed BBSqueeze filter,"+
                                    "======================,";
         } else if(cc_filter_fail && TestCandleColors && bbsq_filter_fail && UseBBSqueeze){
            basketTriggeredStatus = "No realBasket triggerd - Failed at "+failedTrigTime+" GMT,All Trades failed CandelColor or BBSqueeze,"+
                                    "======================,";
         } else if(OnlyPositivetvTradesToRBasket){
            basketTriggeredStatus = "No realBasket triggerd - Failed at "+failedTrigTime+" GMT,No Positive vTrades were found in vBasket,"+
                                    "======================,";         
         } else if(_virtualbasketclosedTime!=0 && selectMarkOption==DoNotCheck) {
            basketTriggeredStatus = "No realBasket triggerd - Closed EndOfDay,"+
                                    "======================,";           
         }  else if (_virtualbasketclosedTime==0) {
             basketTriggeredStatus = "No realBasket triggerd - No trades found in vBasket,"+
                                      "======================,";   
         }
    }                                      
                                      
    SetOpenBasketButtonColors();            
   
    string controls_space="";
    if(!IsTesting()) controls_space=",======================,"; //space for buttons and other stuff

    DisplayStatus(350,20,
                  "xm7_virtual",
                  "== xm7 Virtual Basket ==",
                 /* "======================,"+ */
                  controls_space+
                  virtual_TrigLevelstxt+
                  virtual_MaxMintxt+
                  basketTriggeredStatus+
                  totals_str+                  
                  virtual_trades_list,
                  DisplayFontSize,mainDisplayLength);
}

//=============== Graphic display ===============
void DisplayStatus(int x, int y, string DisplayPreFix, string BoxTitle,string messg, int DisplayPanelFontSize, int& mainDisplay_text_len) {
  
  static string real_bg_length, virtual_bg_length,messg_len,virt_messg_len;
  static int k_prev_real=0, k_prev_virt=0;
  static bool virtmin=false,displymin=false;
  bool redraw_bg=false,show_item=true;
  
  color BoxColor=11184640,ContBoxColor=DarkSlateGray;
  int dy=21,dyTitle=30,dySpace=10; // dy=space between text lines,  dyTitle=space between title txt lines,    dySpace=estra space size
  int space_y=5,k;  //  space_y=Not uses,  k=Size of text message array msg[] 
  string Fonts=fontType,msg[],bg_box_length;
  //string Fonts="Arial",msg[],bg_box_length;
  
  StringToArray(messg,",",msg);
  k=ArraySize(msg);
       
  if(DisplayPreFix=="xm7_Display") {
      show_item=!minimized_display_panel;
      if(!minimized_display_panel) displymin=false; 
      if(show_item && ObjectFind(_xm7_ea_chartid,DisplayPreFix+"Background")<0) redraw_bg=true; 
      if(k!=k_prev_real || StringLen(messg)!=StringLen(messg_len) || (!displymin && minimized_display_panel)) {  
            redraw_bg=true; k_prev_real=k; real_bg_length=bg_box_length; 
            messg_len=messg;
            RemoveObjects(DisplayPreFix+"Text");
            RemoveObjects(DisplayPreFix+"hline");
            RemoveObjects(DisplayPreFix+"Background");
            RemoveObjects(DisplayPreFix+"Title");
            RemoveObjects("OpenBasketButton");
            RemoveObjects("ResetButton");
            RemoveObjects("xm77_Comments");
            RemoveObjects("minimize");
            displymin=true;
       }
  }
  
  if(DisplayPreFix=="xm7_virtual") { 
      show_item=!minimized_virtual_panel;    
      if(!minimized_virtual_panel) virtmin=false;
      if(show_item && ObjectFind(_xm7_ea_chartid,DisplayPreFix+"Background")<0) { redraw_bg=true; virtmin=false;}
      if(k!=k_prev_virt || StringLen(messg)!=StringLen(virt_messg_len) || (!virtmin && minimized_virtual_panel)) {  
            redraw_bg=true; k_prev_virt=k; virtual_bg_length=bg_box_length; 
            virt_messg_len=messg;
            RemoveObjects(DisplayPreFix+"Text"); 
            RemoveObjects(DisplayPreFix+"hline");
            RemoveObjects(DisplayPreFix+"Background");
            RemoveObjects(DisplayPreFix+"Title");
            RemoveObjects("OpenVirtualBasketButton");
            RemoveObjects("minimize");
            virtmin=true;
       }
  }    

  int space_font_size = (int) MathMax(MathRound(DisplayPanelFontSize*2),3);
  int titleBoxHeigth =space_font_size+3;

  int text_len = StringLen(BoxTitle); 
  int titleWidth = (int)(text_len*7.5);
  
   double display_heigth;
   int display_width,xtitle;

   for (int z=0; z<k; z++) { 
         if(StringFind(msg[z],"=====")>-1) continue;
         if(StringLen(msg[z])>text_len) text_len=StringLen(msg[z]);
         //if(StringFindCount(msg[z],"Wednesday")>=2) { text_len=StringLen(msg[z])+4; break; }
   }          
              
   if(DisplayPreFix=="xm7_virtual") {
          display_width=(int)((text_len)*8);   
          display_heigth=(k+0.5)*(2*DisplayPanelFontSize)*1.05; //display_heigth*1.09; 
          if(k<=5)
              display_heigth=6*(2*DisplayPanelFontSize)*1.05; //display_heigth*1.09; 
          
          x=mainDisplay_text_len;
          xtitle=x+(int)((display_width-titleWidth)/2); //xtitle= x+((display_width-195)/2);
   } else { // xm7_Display
          display_width=MathMax((int)((text_len)*8),btn_width+170); //(btn_width+170) is EditBox width plus 25 points 
          display_heigth= k*(2*DisplayPanelFontSize)*0.95;
          mainDisplay_text_len=MathMax(display_width+30,text_len*8+30); // record this for virtualB x position
          xtitle=x+(int)((display_width-titleWidth)/2);
          x_btn= x+(int)((display_width-(btn_width+155))/2); //x+14; btn_width+155 is the text box length
          y_btn=y+titleBoxHeigth+3;
   }

   if(redraw_bg) { 
            if(show_item) SetPanel(DisplayPreFix+"Background",0,x,y+titleBoxHeigth,-(display_width),(int)display_heigth-titleBoxHeigth,ContBoxColor,clrDarkCyan,1,!show_item);
            SetPanel(DisplayPreFix+"Title",0,x,y,-(display_width),titleBoxHeigth,BoxColor,clrYellowGreen,1,!show_item);
   
            if(DisplayPreFix=="xm7_Display" && show_item) {
                  btn_width=140; btn_heigth=25;         
                  //if(ObjectFind(_xm7_ea_chartid,"xm77_OpenBasketButton_"+(string)_xm7_ea_chartid)<0)  
                        BuildButtons(x_btn,y_btn,btn_width, btn_heigth);
            }
            
            if(DisplayPreFix=="xm7_virtual" && show_item) {
                  btn_width=200; btn_heigth=30;      
                  //if(ObjectFind(0,"xm77_OpenVirtualBasketButton_"+(string)_xm7_ea_chartid)!=0) {
                     btn_width=140; btn_heigth=25;  
                     int x_virtualButton=(int)ChartGetInteger(_xm7_ea_chartid,CHART_WIDTH_IN_PIXELS,0)-x-display_width/2-btn_width/2-30; 
                     createButton(_xm7_ea_chartid,"xm77_OpenVirtualBasketButton",x_virtualButton,chartH,(display_width/2),btn_heigth,clrWhite,clrTeal,11,"Open Virtual Basket",100,false);
                   //}
            }                         
   }      

   //==================== display title =================================  
  drawFixedLbl(DisplayPreFix+"Text", BoxTitle,CORNER_RIGHT_UPPER, xtitle, y+5, DisplayPanelFontSize, Fonts, White, false);
  y+=dyTitle; 
  
  if(DisplayPreFix=="xm7_Display")
      drawFixedLbl("xm7_minimizeDisplay", "--",CORNER_RIGHT_UPPER, x+3, y-25, DisplayPanelFontSize, Fonts, White, false);
      
  if(DisplayPreFix=="xm7_virtual")
      drawFixedLbl("xm7_minimizeVirtualDisplay", "--",CORNER_RIGHT_UPPER, x+3, y-25, DisplayPanelFontSize, Fonts, White, false);


  if ((k==0 && messg=="") || !show_item)  return;
 
 //==================== display normal operation =================================
 for (int i=0; i<k; i++) {
      //if(DisplayPreFix=="xm7_Display" && i==3) y_fontsizebtn=y; // Draw fontsize buttons
       
       int z = x;
       //if(i==0) z =  x + (int)((display_width-(StringLen(msg[i])*8))/2); //This will center the first vBasket text item  
    
      if(StringFind(msg[i],"=====")>-1) { 
           SetPanel(DisplayPreFix+"hline"+IntegerToString(i),0,x+10,y+12,-(display_width-20),1,ContBoxColor,clrWhite,1,!show_item);
      } else {
           drawFixedLbl(DisplayPreFix+"Text"+IntegerToString(i), msg[i], CORNER_RIGHT_UPPER, z+10, y, DisplayPanelFontSize, Fonts, White, false);
      }      
      
      y+=dy;
 }
 
}

void SetPanel(string name,int sub_window,int x,int y,double width,int height,color bg_color,color border_clr,int border_width,bool backgrnd)
  {
   if(ObjectFind(_xm7_ea_chartid,name)<0)
       ObjectCreate(_xm7_ea_chartid,name,OBJ_RECTANGLE_LABEL,sub_window,0,0);

   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_XSIZE,(int)width);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_COLOR,border_clr);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_WIDTH,border_width);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_BACK,backgrnd);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_ZORDER,0);
   ObjectSetInteger(_xm7_ea_chartid,name,OBJPROP_BGCOLOR,bg_color);
  }

 void drawFixedLbl(string objname, string s, int Corner, int DX, int DY, int FSize, string Font, color c, bool bg) {

    if (ObjectFind(_xm7_ea_chartid,Symbol()+"_"+objname) < 0) {
        ObjectCreate(_xm7_ea_chartid,Symbol()+"_"+objname, OBJ_LABEL, 0, 0, 0);
    } 
    ObjectSet(Symbol()+"_"+objname, OBJPROP_CORNER, Corner);
    ObjectSet(Symbol()+"_"+objname, OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
    ObjectSet(Symbol()+"_"+objname, OBJPROP_XDISTANCE, DX);
    ObjectSet(Symbol()+"_"+objname, OBJPROP_YDISTANCE, DY);
    ObjectSet(Symbol()+"_"+objname,OBJPROP_BACK, bg);
    ObjectSetText(Symbol()+"_"+objname, s, FSize, Font, c);
}

void RemoveObjects(string sz8) {  
   int t1=ObjectsTotal(_xm7_ea_chartid);
   while(t1>=0) {  
      if (StringFind(ObjectName(_xm7_ea_chartid,t1),sz8,0)>-1) ObjectDelete(_xm7_ea_chartid,ObjectName(_xm7_ea_chartid,t1)); 
      t1--;
    }
}

string getStringOf(int dayofweek_) {

   switch(dayofweek_) {
      case(Sunday): return("Sunday"); break;
      case(Monday): return("Monday"); break;
      case(Tuesday): return("Tuesday"); break;
      case(Wednesday): return("Wednesday"); break;
      case(Thursday): return("Thursday"); break;
      case(Friday): return("Friday"); break;
      case(Saturday): return("Saturday"); break;
      default: return("Monday");
   }

}

string StringChangeToLowerCase(string sText) {
  // Example: StringChangeToLowerCase("oNe mAn"); // one man
  int iLen=StringLen(sText), i, iChar;
  for(i=0; i < iLen; i++) {
    iChar=(int)StringGetChar(sText, i);  
    if(iChar >= 65 && iChar <= 90) sText=StringSetChar(sText, i, (ushort)(iChar+32));
  }
  return(sText);  
}
 
void RemoveGlobals(string _string, string _except="") {  //Remove everything (_string) except what is called out in var _except
   int t1=GlobalVariablesTotal();
   string except[];
   
   if(_except!="") {
         if(StringFind(_except,",")>0) StringToArray(_except,",",except);
         if(StringFind(_except,",")==-1) { ArrayResize(except,1); except[0]=_except; }
   }
   while(t1>=0) {  
      if(_except!="")
         if (StringFind(GlobalVariableName(t1),_except)>-1) { t1--; continue; }
               
      if (StringFind(GlobalVariableName(t1),_string,0)>-1) GlobalVariableDel(GlobalVariableName(t1));
      t1--;
    }
}

bool CheckMargin(string symbl, double lotzz, int optype) {  
   
   refreshRates();
   
   myTickValue = MarketInfo(symbl,MODE_TICKVALUE);
   margin=MarketInfo(symbl, MODE_MARGINREQUIRED);
 
   if(myTickValue!=0) {         
      double marginForLots = lotzz * margin;
      
      if(AccountMargin()==0) return(true);
      
      if (AccountEquity() == 0) { 
         Print(TimeToStr(TimeCurrent())+": No Trade due to not enough or no funds.  Your current funds are $"+DoubleToStr(AccountEquity(),2)); 
         return(false); 
      }// end if (AccountEquity() == 0) 
      
      if(MarginLevel>0 && (AccountEquity()/AccountMargin())<=(MarginLevel/100)) {
         Print(TimeToStr(TimeCurrent())+": You've reached margin level of "+DoubleToStr(MarginLevel,1)+"%. No more trades will be opened");
         return(false);  
      }
   }
   return(true);   
}

void GetBasketStopTake(double& sl, double& tp){
   tp=0; sl=0;
    
   if(Use_ATR) GetATRStopLoss(sl);
   
   if(TP_to_SL_Ratio>0) tp=sl*TP_to_SL_Ratio;
   if(InvertRatio && TP_to_SL_Ratio>0) tp=sl/TP_to_SL_Ratio;
}

void GetATRStopLoss(double& sl){
   int cnt=0, p=1;
   sl=0;
   
   refreshRates();
   
   for(int x=0; x<=OrdersTotal()-1; x++) {
      if(!OrderSelect(x,SELECT_BY_POS)) continue; 
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(MarketInfo(OrderSymbol(),MODE_DIGITS)==3 || MarketInfo(OrderSymbol(),MODE_DIGITS)==5) p=10;
       
      Print(iATR(OrderSymbol(),ATRTimeFrame,ATRPeriod,0),"  ",iATR(OrderSymbol(),ATRTimeFrame,ATRPeriod,0)/(p*MarketInfo(OrderSymbol(),MODE_POINT)));
      sl+=iATR(OrderSymbol(),ATRTimeFrame,ATRPeriod,0)/(p*MarketInfo(OrderSymbol(),MODE_POINT));
      cnt++;
   }       

   sl=sl*ATR_Multiplier;
   sl=NormalizeDouble(sl,1);
}

void MonitorTrailingStopEachTrade() {
    double ProfitLock=0,take_profit=0, new_stop=0;
    double symbpoint, ask, bid, StartProfitLock=0,level;
    
    refreshRates();
    symbpoint=MarketInfo(OrderSymbol(),MODE_POINT);
    if(MarketInfo(OrderSymbol(),MODE_DIGITS)==3 || MarketInfo(OrderSymbol(),MODE_DIGITS)==5)
      symbpoint=10*symbpoint;
      
    ask=MarketInfo(OrderSymbol(),MODE_ASK);
    bid=MarketInfo(OrderSymbol(),MODE_BID);  
    
    ProfitLock=Set_TrailingStop_On_EachTrade*symbpoint;
    level=OrderOpenPrice();

    if(OrderType()==OP_BUY && OrderProfit()>0) { 

       if(OrderStopLoss()>=OrderOpenPrice()) {
            level=OrderStopLoss();
            ProfitLock=2*Set_TrailingStop_On_EachTrade*symbpoint;
      }       
 
      if((bid-level)>=ProfitLock) {
            new_stop=bid-Set_TrailingStop_On_EachTrade*symbpoint;     
            trd=OrderModify(OrderTicket(),OrderOpenPrice(),new_stop,OrderTakeProfit(),0,Blue);
            return;
      }   

    }    
    
    if(OrderType()==OP_SELL && OrderProfit()>0) {
    
       if(OrderStopLoss()<=OrderOpenPrice()) {
            level=OrderStopLoss();
            ProfitLock=2*Set_TrailingStop_On_EachTrade*symbpoint; 
      }       
 
       if((level-ask)>=ProfitLock) { 
            new_stop=ask+Set_TrailingStop_On_EachTrade*symbpoint;         
            trd=OrderModify(OrderTicket(),OrderOpenPrice(),new_stop,OrderTakeProfit(),0,Red);
            return;
       }     
  
    }                 
}

void MonitorTrailingBasket(double _basket_profit, double& _basket_laststop) {
   
    static double startBasketLock;
      
    if(_basket_laststop==-1)  {

         startBasketLock=(GlobalVariableCheck("xm7_basket_settBasketLock_"+_xm7_magicnumber_str)?
                                GlobalVariableGet("xm7_basket_settBasketLock_"+_xm7_magicnumber_str):
                                setStartLocking);
        if(GlobalVariableCheck("xm7_basket_stop_"+_xm7_magicnumber_str))
            _basket_laststop=GlobalVariableGet("xm7_basket_stop_"+_xm7_magicnumber_str);    
    }
    
    if(_basket_profit>=startBasketLock && setLockDelta>0) { 
       
         if(StepFactor==TrailStop && _TrailStop>0) 
            _basket_laststop=(_basket_laststop==-1 && SetBEonFirstTrail?0.5:_basket_profit-_TrailStop);  

         /*if(StepFactor==PercentOfProfit)
             _basket_laststop=NormalizeDouble((_basket_profit*(LockPercentLevel/100)),1);*/
		  
         startBasketLock=_basket_profit+setLockDelta;
         
         GlobalVariableSet("xm7_basket_stop_"+_xm7_magicnumber_str,_basket_laststop);
         GlobalVariableSet("xm7_basket_settBasketLock_"+_xm7_magicnumber_str,startBasketLock);     
    }       
}

double correctLots(string pair,double lotsToCorrect) {   
      double vol=lotsToCorrect;
      refreshRates();
      lot_min=MarketInfo(pair,MODE_MINLOT);
      lot_max=MarketInfo(pair,MODE_MAXLOT);
      if(lotsToCorrect<lot_min) vol  =  lot_min;
      if(lotsToCorrect>lot_max) vol  =  lot_max; 
      return(vol);
}

void BuildButtons(int _x, int _y, int& _btn_width, int& _btn_heigth) {

   //chartW=450; // 450 from left side;
	//chartH=50;// keep top of chart steady, using y now
	
	if(IsTesting()) return;
	
	chartH=_y;
	
	int y_textBox=chartH+_btn_heigth+2;

	chartW=(int)ChartGetInteger(_xm7_ea_chartid,CHART_WIDTH_IN_PIXELS,0)- _btn_width-_x;  //  make x  _btn_width bigger moves button to left
	int X2ndButton=chartW-150; // Reset Basket
	int x_textBox=chartW-152;  //chartW-237;	
   
   createButton(_xm7_ea_chartid,"xm77_OpenBasketButton",X2ndButton,chartH,_btn_width,_btn_heigth,clrWhite,clrBlue,11,"Open Basket",100,false); 
   EnableButton(_xm7_ea_chartid,true,"xm77_OpenBasketButton_"); 
   
   createButton(_xm7_ea_chartid,"xm77_ResetButton",chartW,chartH,_btn_width,_btn_heigth,clrLightGray,clrOliveDrab,11,"Reset EA",100,false);
   
   //Create Input text box for user comments
   EditCreate(_xm7_ea_chartid,"xm77_Comments_"+(string)_xm7_ea_chartid,x_textBox,y_textBox,(_btn_width+155),_btn_heigth,xm7_comments);
     
   //If user reloads EA and there are open trade, set buttons accordingly
   if(_OrdersTotal()>0) 
      SetOpenBasketButtonColors();
}

void createButton(long chart_id, string btn_string, int x, int y, int btnwidth, int btnheigth, color clr, color bg_clr, int fontsize, string btn_txt ,int z_order, bool btn_state) {
	ObjectDelete(chart_id,btn_string+"_"+(string)chart_id);
   ObjectCreate(chart_id,btn_string+"_"+(string)chart_id,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_XSIZE,btnwidth);
   ObjectSetInteger(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_YSIZE,btnheigth);
   ObjectSetInteger(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_BGCOLOR, bg_clr);
   ObjectSetInteger(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_FONTSIZE,fontsize);
   ObjectSetString(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_TEXT,btn_txt);
   ObjectSetInteger(chart_id, btn_string+"_"+(string)chart_id, OBJPROP_ZORDER, z_order);  //Get high priority for chart event
   ObjectSetInteger(chart_id,btn_string+"_"+(string)chart_id,OBJPROP_STATE,btn_state); // enabled state/button unpressed
}

bool ButtonMove(const long   chart_ID=0,    // chart's ID 
                const string name="Button", // button name 
                const int    x=0,           // X coordinate 
                const int    y=0)           // Y coordinate 
  { 
   ResetLastError(); 
//--- move the button 
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x)) { 
      Print(__FUNCTION__, ": failed to move X coordinate of the button! Error code = ",GetLastError()); 
      return(false); 
   } 
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y)) { 
      Print(__FUNCTION__, ": failed to move Y coordinate of the button! Error code = ",GetLastError()); 
      return(false); 
     } 
   return(true); 
  }

void TrackButtonPosition(int _x, int _y, int _btn_width, int _btn_heigth) {
   //int y, x, x2;
   int y, x, x2, x_tbox,y_tbox;  //x3, x4, x5, x4
   string thisbutton[];
   
   //When we go out of focus this always ends up as 852
   //So to not affect the button x position we just ignore this when 
   //user changes charts
   if(ChartGetInteger(_xm7_ea_chartid,CHART_WIDTH_IN_PIXELS,0)==852) return;
   
   y=_y; // keep top of chart steady
	x=(int)ChartGetInteger(_xm7_ea_chartid,CHART_WIDTH_IN_PIXELS,0) - _btn_width-_x; // make number after _btn_width bigger moves button to left
	x2=x-150;// Reset
   x_tbox=x-152; //x-237;
   y_tbox=y+_btn_heigth+2;	
   
   //vButton stuff
   int vBtn_x_vButton=-1;
   if(ObjectFind(_xm7_ea_chartid,"xm77_OpenVirtualBasketButton_"+(string)_xm7_ea_chartid)==0) {
      int vBtn_btn_width=(int)ObjectGetInteger(_xm7_ea_chartid,"xm77_OpenVirtualBasketButton_"+(string)_xm7_ea_chartid,OBJPROP_XSIZE); 
      int vBtn_displaywidth_vTitlePanel=(int)ObjectGetInteger(_xm7_ea_chartid,"xm7_virtualTitle",OBJPROP_XSIZE);
      int vBtn_x_TitlePanel=(int)ObjectGetInteger(_xm7_ea_chartid,"xm7_virtualTitle",OBJPROP_XDISTANCE);
      vBtn_x_vButton=(int)ChartGetInteger(_xm7_ea_chartid,CHART_WIDTH_IN_PIXELS,0)-vBtn_x_TitlePanel+vBtn_displaywidth_vTitlePanel/2-vBtn_btn_width/2+10; //virtual Button
   }
	
	//y=(int)ChartGetInteger(_xm7_ea_chartid,CHART_HEIGHT_IN_PIXELS,0)-2*_btn_heigth+1; // keep bottom of chart steady 
	if (x!=chartW || y!=chartH) {
	   ButtonMove(_xm7_ea_chartid,"xm77_OpenBasketButton_"+(string)_xm7_ea_chartid,x2,y);
      ButtonMove(_xm7_ea_chartid,"xm77_ResetButton_"+(string)_xm7_ea_chartid,x,y);
      if(ObjectFind(_xm7_ea_chartid,"xm77_OpenVirtualBasketButton_"+(string)_xm7_ea_chartid)==0)
            ButtonMove(_xm7_ea_chartid,"xm77_OpenVirtualBasketButton_"+(string)_xm7_ea_chartid,vBtn_x_vButton,y);   //vButton move  
      EditMove(_xm7_ea_chartid,"xm77_Comments_"+(string)_xm7_ea_chartid,x_tbox,y_tbox);
              
	   chartW=x;
	   chartH=y;
	}  
}

void OnChartEvent(const int id, const long &lparam,const double &dparam, const string &sparam){
                  
         string msg,close_msg,result[];

         if(id==CHARTEVENT_OBJECT_CLICK)
                   if(StringFind(sparam,"xm7_minimizeDisplay")>-1) 
                        if(!minimized_display_panel) { minimized_display_panel=true; } else if(minimized_display_panel) minimized_display_panel=false; 
             
         if(id==CHARTEVENT_OBJECT_CLICK)
                   if(StringFind(sparam,"xm7_minimizeVirtualDisplay")>-1)
                        if(!minimized_virtual_panel){ minimized_virtual_panel=true; } else if(minimized_virtual_panel) minimized_virtual_panel=false; 
     
         if(id==CHARTEVENT_OBJECT_CLICK)
                  if(sparam=="xm77_ResetButton_"+(string)_xm7_ea_chartid) { //Reset button pressed          
                       if(!IsMarketOpen) {
                             MessageBox("Markets is closed", DisplayTitle, MB_ICONEXCLAMATION);
                             ObjectSetInteger(_xm7_ea_chartid,"xm77_ResetButton_"+(string)_xm7_ea_chartid,OBJPROP_STATE,false); //unpress button
                             return;
                       }                         
                       if(_OrdersTotal()==0) {
                             ClickBtn(_xm7_ea_chartid,true,"xm77_ResetButton_"); Sleep(300); ClickBtn(_xm7_ea_chartid,false,"xm77_ResetButton_");
                             RemoveGlobals("_"+_xm7_magicnumber_str); //Clear all globals for this Basket                            
                             resetAllVariables();                             
                             OpenNow=false; B1Done=false;
                             if(LogData && FileIsExist(LogFileName)) FileDelete(LogFileName);                   
                             EnableButton(0,true,"xm77_ResetButton_");
                             
                       } else {
                           EnableButton(_xm7_ea_chartid,false,"xm77_ResetButton_"); // keeps button in disables state
                       }
                  }                        
                          
          if(id==CHARTEVENT_CHART_CHANGE) { 
                  if(ObjectFind(_xm7_ea_chartid,"xm77_OpenBasketButton_"+(string)_xm7_ea_chartid)==0)
                        TrackButtonPosition(x_btn,y_btn,btn_width, btn_heigth);
          }

          if(id==CHARTEVENT_OBJECT_ENDEDIT)  {  
                 xm7_comments=StringTrimLeft(StringTrimRight(ObjectGetString(_xm7_ea_chartid,sparam,OBJPROP_TEXT)));                        
                 RemoveGlobals("xm7_cmnts_"+_xm7_magicnumber_str); //only removes xm7_cmnt global
                 if(xm7_comments=="") { xm7_comments=" === Notes === "; return; }
                 ObjectSetString(_xm7_ea_chartid,sparam,OBJPROP_TEXT,xm7_comments); 
                 GlobalVariableSet("xm7_cmnts_"+_xm7_magicnumber_str+"_"+xm7_comments,0); 
          }
          
          //Open Basket Manual Button has been pressed ==============================================
           if(id==CHARTEVENT_OBJECT_CLICK)
                   if(sparam=="xm77_OpenBasketButton_"+(string)_xm7_ea_chartid) {             
                           if(!IsMarketOpen) {
                                 MessageBox("Markets is closed", DisplayTitle, MB_ICONEXCLAMATION);
                                 ObjectSetInteger(_xm7_ea_chartid,"xm77_OpenBasketButton_"+(string)_xm7_ea_chartid,OBJPROP_STATE,false); //unpress button
                                 return;
                           }     
                                 
                            if(_OrdersTotal()==0)  { 
                                    ClickBtn(_xm7_ea_chartid,true,"xm77_OpenBasketButton_"); Sleep(300); ClickBtn(_xm7_ea_chartid,false,"xm77_OpenBasketButton_"); Sleep(50);                          
                                    OpenNow=true;
        
                                    resetAllVariables();
                                    GetPairs();
                                   // if(!UseVirtualBasket) GetPairs();
                                    //if(UseVirtualBasket) OpenVirtualTrades();

                                    if(LogData) SetLogFile(LogFileName);
                                    setCloseHours();
                                    OpenBasket(); 
                                    return;
                            }
                  
                            if(_OrdersTotal()>0) {
                                    ClickBtn(_xm7_ea_chartid,true,"xm77_OpenBasketButton_"); Sleep(100); ClickBtn(_xm7_ea_chartid,false,"xm77_OpenBasketButton_"); Sleep(50);
                                    CloseBasket(); return;                               
                            }                                                                      
                   }
           
           //Open Virtual Basket Manual Button has been pressed ==============================================        
           if(id==CHARTEVENT_OBJECT_CLICK)
                if(sparam=="xm77_OpenVirtualBasketButton_"+(string)_xm7_ea_chartid) {        
                        if(!IsMarketOpen) {
                                 MessageBox("Markets is closed", DisplayTitle, MB_ICONEXCLAMATION);
                                 ObjectSetInteger(_xm7_ea_chartid,"xm77_OpenVirtualBasketButton_"+(string)_xm7_ea_chartid,OBJPROP_STATE,false); //unpress button
                                 return;
                           }     
                       
                        if(ArraySize(_virtualOrders)==0) {
                              ClickBtn(_xm7_ea_chartid,true,"xm77_OpenVirtualBasketButton_"); Sleep(300); ClickBtn(_xm7_ea_chartid,false,"xm77_OpenVirtualBasketButton_"); Sleep(50); 
                              resetAllVariables();
                              _xm7_RealBasketClosedHr=0; GlobalVariableDel("xm7_RealBasketClosedHr_"+_xm7_magicnumber_str); 
                              setCloseHours(); 
                              OpenVirtualTrades();  //Note getPairs() is used in this function
                              if(ArraySize(_virtualOrders)>0) { 
                                    if(letEASetNegTrig) { _VirtualUpperTriggerLevel=0; _VirtualLowerTriggerLevel=MathAbs(getNegativeTrigger(ArraySize(_virtualOrders))); } 
                                    _xm7_vBasketTriggeredHour=timeGMT; GlobalVariableSet("xm7_vBasketTriggerHour_"+_xm7_magicnumber_str,(double)_xm7_vBasketTriggeredHour);
                                    if(!IsTesting()) backupVirtualArray("virtualOrders_"+_xm7_magicnumber_str); 
                                    if(_continueVBMonitor) { _continueVBMonitor=false;  GlobalVariableDel("xm7_continueVBMonitor_"+_xm7_magicnumber_str); }
                              } else if (continueProcessingVB){
                                    if(!_continueVBMonitor) { _continueVBMonitor=true; GlobalVariableSet("xm7_continueVBMonitor_"+_xm7_magicnumber_str,1); }
                              }
                        }  else {
                              ClickBtn(_xm7_ea_chartid,true,"xm77_OpenVirtualBasketButton_"); Sleep(300); ClickBtn(_xm7_ea_chartid,false,"xm77_OpenVirtualBasketButton_"); Sleep(50); 
                              MessageBox("Virtual basket already opened.  Hit Reset Button to start a new one",DisplayTitle,MB_ICONHAND);
                        }
                 }                    
                   
          if(id==CHARTEVENT_OBJECT_CLICK) 
                  if(sparam=="xm7_help_url") ShellExecuteW(NULL, "Open",ObjectGetString(0,sparam,OBJPROP_TEXT), "0" , "", 0);                   
                      
}

void closeTradeButton() {
      
     ClickBtn(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); Sleep(100); ClickBtn(_xm7_ea_chartid,false,"xm77_CloseTradesButton_"); Sleep(50); EnableButton(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); 
                     
     if(_OrdersTotal()>0) {
            ClickBtn(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); Sleep(100); ClickBtn(_xm7_ea_chartid,false,"xm77_CloseTradesButton_"); Sleep(50);
            CloseAllTrades();
            EnableButton(_xm7_ea_chartid,true,"xm77_CloseTradesButton_");
     }                                                                                            
     
     ObjectSetInteger(0, "xm77_CloseTradesButton_"+(string)_xm7_ea_chartid, OBJPROP_STATE, false);  

}


 void ClickBtn(ulong chart_id,bool state, string btn) {
 
   if(state) {
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR, Orange);
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_STATE,true);
   } else {
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_COLOR, LightGray);
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR, Gray);       
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_STATE,false);
   }
 
 }

 void EnableButton(ulong chart_id,bool state, string btn) {
   color clr_=White; color bgclr_=Red; 
   if(btn=="xm77_ResetButton_" || btn=="xm77_VirtualBasketClearButton_") { clr_=LightGray; bgclr_=clrOliveDrab; }
   if(btn=="xm77_OpenBasketButton_" || btn=="xm77_OpenVirtualBasketButton_") { clr_=White; bgclr_=Blue; };
   
   if(state) {
       if((btn=="xm77_ResetButton_" || btn=="xm77_VirtualBasketClearButton_") && ObjectGetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR)==bgclr_) return;
       if((btn=="xm77_OpenBasketButton_" || btn=="xm77_OpenVirtualBasketButton_") && ObjectGetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR)==bgclr_) return;  
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_STATE,false); // enabled state/button unpressed
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_COLOR, clr_);
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR, bgclr_);
       if(btn=="xm77_OpenBasketButton_") 
            ObjectSetString(_xm7_ea_chartid,"xm77_OpenBasketButton_"+(string)_xm7_ea_chartid,OBJPROP_TEXT,"Open Basket");
   } else {
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_STATE,false);// disabled state
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_COLOR, LightGray);
       ObjectSetInteger(_xm7_ea_chartid,btn+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR, Gray);
   }
   
 } 

void SetOpenBasketButtonColors(){
         
         string btn_str="xm77_OpenBasketButton_"; 
         
         if(_OrdersTotal()>0 && ObjectGetString(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_TEXT)=="Open Basket") {
               ObjectSetString(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_TEXT,"Close Basket"); 
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_COLOR, White);
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR, Red);
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_STATE,false);
               
               btn_str="xm77_ResetButton_";
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR, Gray);
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_STATE,false);
               return;
          } 

         if(_OrdersTotal()==0 && ObjectGetString(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_TEXT)=="Close Basket") {
               ObjectSetString(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_TEXT,"Open Basket"); 
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_COLOR, White);
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR, Blue);
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_STATE,false);
               
               btn_str="xm77_ResetButton_";
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_BGCOLOR, clrOliveDrab);
               ObjectSetInteger(_xm7_ea_chartid,btn_str+(string)_xm7_ea_chartid,OBJPROP_STATE,false);
               
               return;
          }        
} 

bool EditCreate(const long             chart_ID=0,               // chart's ID
                const string           name="Edit",              // object name
                const int              x=0,                      // X coordinate
                const int              y=0,                      // Y coordinate
                const int              width=50,                 // width
                const int              height=18,                // height                                
                const string           text="=== Comments ===",              // text
                const int              sub_window=0,             // subwindow index
                const string           font="Arial",             // font
                const int              font_size=10,             // font size
                const ENUM_ALIGN_MODE  align=ALIGN_CENTER,       // alignment type
                const bool             read_only=false,          // ability to edit
                const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                const color            clr=clrBlack,             // text color
                const color            back_clr=clrWhite,        // background color
                const color            border_clr=clrNONE,       // border color
                const bool             back=false,               // in the background
                const bool             selection=false,          // highlight to move
                const bool             hidden=true,              // hidden in the object list
                const long             z_order=0)                // priority for mouse click
  {
  
//--- reset the error value
   ResetLastError();
//--- create edit field
   if(!ObjectCreate(chart_ID,name,OBJ_EDIT,sub_window,0,0))
     {
      Print(__FUNCTION__,
            ": failed to create \"Edit\" object! Error code = ",GetLastError());
      return(false);
     }
//--- set object coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set object size
   ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set the type of text alignment in the object
   ObjectSetInteger(chart_ID,name,OBJPROP_ALIGN,align);
//--- enable (true) or cancel (false) read-only mode
   ObjectSetInteger(chart_ID,name,OBJPROP_READONLY,read_only);
//--- set the chart's corner, relative to which object coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set text color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set background color
   ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
//--- set border color
   ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_COLOR,border_clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Move Edit object                                                 |
//+------------------------------------------------------------------+
bool EditMove(const long   chart_ID=0,  // chart's ID
              const string name="Edit", // object name
              const int    x=0,         // X coordinate
              const int    y=0)         // Y coordinate
  {
//--- reset the error value
   ResetLastError();
//--- move the object
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x))
     {
      Print(__FUNCTION__,
            ": failed to move X coordinate of the object! Error code = ",GetLastError());
      return(false);
     }
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y))
     {
      Print(__FUNCTION__,
            ": failed to move Y coordinate of the object! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
  } 
    
void resetMaxMin(double& max, double& min, string& maxTime, string& minTime){
      max=0; GlobalVariableDel("xm7_max_week_gain_"+_xm7_magicnumber_str); 
      maxTime=""; GlobalVariableDel("xm7_maxtime_"+_xm7_magicnumber_str);
      min=0; GlobalVariableDel("xm7_min_week_gain_"+_xm7_magicnumber_str); 
      minTime=""; GlobalVariableDel("xm7_mintime_"+_xm7_magicnumber_str);
}

void GetMinMax_week(double currgain, double& max, double& min, string& maxTime, string& minTime) {
      string time=TimeToString(timeGMT);
      double dTime=(double)timeGMT;
      
      if(GlobalVariableCheck("xm7_max_week_gain_"+_xm7_magicnumber_str))
         if(GlobalVariableTime("xm7_max_week_gain_"+_xm7_magicnumber_str)<iTime(Symbol(),PERIOD_W1,0))
            { resetMaxMin(max, min, maxTime, minTime); return; }
              
      if(currgain>max) { 
         max=currgain; GlobalVariableSet("xm7_max_week_gain_"+_xm7_magicnumber_str,max); 
         maxTime=time; GlobalVariableSet("xm7_maxtime_"+_xm7_magicnumber_str,dTime);
      }
      if(currgain<min) { 
         min=currgain; GlobalVariableSet("xm7_min_week_gain_"+_xm7_magicnumber_str,min); 
         minTime=time; GlobalVariableSet("xm7_mintime_"+_xm7_magicnumber_str,dTime);
      }
}

void LogToFile(string fileName, string time, string totaldata, string maxdata, string mindata){
      int      CREATE   = FILE_WRITE|FILE_TXT|FILE_ANSI;
      int      APPEND   = FILE_READ|CREATE;
      int   handle   = FileOpen(fileName, APPEND,",");

      if(handle != INVALID_HANDLE){
         FileSeek(handle, 0, SEEK_END);
         if(StrToDouble(totaldata)!=0 || StrToDouble(maxdata)!=0 || StrToDouble(mindata)!=0) {
            FileWrite(handle,time,totaldata,maxdata,mindata);
            //FileWrite(handle,OrdId[i],OrdSym[i],OrdTyp[i],OrdLot[i],OrdPrice[i],OrdSL[i],OrdTP[i],OrdComm[i]);              
         } else {
            FileWrite(handle,"Broker: " + AccountCompany(),"");  
            FileWrite(handle,"Basket MagicNumber: "+_xm7_magicnumber_str);
            FileWrite(handle,"Basket Started: " + TimeToStr(timeGMT,TIME_DATE)+" "+time,"\n");
            FileWrite(handle,"Hour","Running Gain","Max Gain","Min Gain(DD)");
         }  
         FileClose(handle);
      }
}

void SetLogFile(string& _logfilename) {
      string title="xm7_CcfpLog_";
      string _datetime;
      
      _datetime=TimeToStr(timeGMT,TIME_DATE); StringReplace(_datetime,".","");
      _datetime=_datetime+"_"+getTimeMin(timeGMT); StringReplace(_datetime,":","");
      
      _logfilename=title+_datetime+".csv";
       
      if(FileIsExist(_logfilename)) FileDelete(_logfilename);
      if(GlobalVariableCheck(_logfilename+"_"+_xm7_magicnumber_str)) GlobalVariableDel(_logfilename+"_"+_xm7_magicnumber_str);      
      GlobalVariableSet(_logfilename+"_"+_xm7_magicnumber_str,0);  

      LogToFile(_logfilename,getTimeMin(timeGMT),"0","0","0");     
}

void removeLogs() {
   string result[],breakdown[],date_str,time_str,filedatetime;
   bool deletelogs=false;
   if(FilesInFolder("xm7_CcfpLog*csv",0,result)==0) return;
   for(int x=0; x<ArraySize(result); x++) {
         //xm7_CcfpLog_20190408_0507.csv
         StringToArray(result[x],"_",breakdown);
         date_str=StringSubstr(breakdown[2],0,4)+"."+StringSubstr(breakdown[2],4,2)+"."+StringSubstr(breakdown[2],6,2);
         time_str=StringSubstr(breakdown[3],0,2)+":"+StringSubstr(breakdown[3],2,2);
         filedatetime=date_str+" "+time_str;
         
         if(deleteLogsFrequency==daily)
               if(timeGMT-StringToTime(filedatetime)>PERIOD_D1*60) { deletelogs=true; break; }

         if(deleteLogsFrequency==weekly)
               if(timeGMT-StringToTime(filedatetime)>PERIOD_W1*60) { deletelogs=true; break; }
               
         if(deleteLogsFrequency==monthly)
               if(timeGMT-StringToTime(filedatetime)>PERIOD_MN1*60) { deletelogs=true; break; }                              
   }
   
   if(deletelogs)
        for(int x=0; x<ArraySize(result); x++) FileDelete(result[x]);   
}

string getTimeMin(datetime _time){
   return(
       (TimeHour(_time)<10?"0"+(string)TimeHour(_time):(string)TimeHour(_time))+":"+
       (TimeMinute(_time)<10?"0"+(string)TimeMinute(_time):(string)TimeMinute(_time))
   );
}
 
 int DSTShift(){
    datetime dstStart, dstEnd;
    bool _usDst=false, _euroDst=false;
        
    AmericanDST(TimeYear(TimeCurrent()),dstStart,dstEnd);
    if(TimeCurrent()>=dstStart && TimeCurrent()<=dstEnd) _usDst=true; 

    EuropeanDST(TimeYear(TimeCurrent()),dstStart,dstEnd);
    if(TimeCurrent()>=dstStart && TimeCurrent()<=dstEnd) _euroDst=true;
 
    if(_usDst && !_euroDst) return(1);
    if(_usDst && _euroDst) return(2);
    if(!_usDst && _euroDst) return(3);
    if(!_usDst && !_euroDst) return(4);
 
   return(0);  
 }
 
 bool AmericanDST(int year, datetime& DST_Start, datetime& DST_End) {
   if (year < 1987) 
      { Print ("AmericanDST(): Invalid year."); return (false); }
   
   int DST_start_dom = 0, DST_end_dom = 0;
   if (year >= 1987 && year <= 2006) {
      DST_start_dom = (int)(1 + MathMod((2 + 6*year - year/4), 7));   
      DST_end_dom = (int)(31 - MathMod((1 + 5*year/4), 7));           
      DST_Start = StrToTime(StringConcatenate(year, ".04.01")) + ((DST_start_dom - 1) * 86400) + 7200;  // first Sunday in April
      DST_End = StrToTime(StringConcatenate(year, ".10.01")) + ((DST_end_dom - 1) * 86400) + 7200;      // last Sunday in October
   }
   else if (year >= 2007) {
      DST_start_dom = (int)(14 - MathMod((1 + 5*year/4), 7));        
      DST_end_dom = (int)(7 - MathMod((1 + 5*year/4), 7));             
      DST_Start = StrToTime(StringConcatenate(year, ".03.01")) + ((DST_start_dom - 1) * 86400) + 7200;  // second Sunday in March
      DST_End = StrToTime(StringConcatenate(year, ".11.01")) + ((DST_end_dom - 1) * 86400) + 7200;      // first Sunday in November
   }
   
   return (true);
} 

bool EuropeanDST(int year, datetime& DST_Start, datetime& DST_End) {
   if (year < 1996) 
      { Print ("EuropeanDST(): Invalid year."); return (false); }

   int DST_start_dom = 0, DST_end_dom = 0;
   DST_start_dom = (int)(31 - MathMod((4 + MathFloor(5*year/4)), 7));
   DST_end_dom = (int)(31 - MathMod((1 + MathFloor(5*year/4)), 7));
   DST_Start = StrToTime(StringConcatenate(year, ".03.01")) + ((DST_start_dom - 1) * 86400) + 3600;     // last Sunday in March 
   DST_End = StrToTime(StringConcatenate(year, ".10.01")) + ((DST_end_dom - 1) * 86400) + 7200;         // last Sunday in October

   return (true);
}

void GetGMTInfo(double& _LocalGMToffSet, double& _BrokerGMToffSet){

    bool oddnum=false; //This is for this shifts that have 0.5 (like in india somewhere)
    if(MathMod(MathAbs(TimeGMTOffset()),2)==1) oddnum=true; 
    
    datetime tGMT=getGMTFromWeb(); //Print(TimeToString(tGMT));

    int count=0;  
    if(tGMT==0) { 
            while(TimeMinute(TimeCurrent())!=TimeMinute(TimeGMT())) { count++; if(count==3) return; Sleep(1000); }
            tGMT=TimeGMT();
            if(debugTime) Print("Adjusted was made. Broker/GMT are in sync:  brokerTime: ",TimeToStr(TimeCurrent()),"    gmtTime: ",TimeToStr(tGMT),"  MagicNumber: ",(string)MagicNumber);         
    }   

    int hrBRK=TimeHour(TimeCurrent());
    if(DayOfWeek()==TimeDayOfWeek(tGMT)+1) hrBRK=24+hrBRK;    

    int hrGMT=TimeHour(tGMT);
    if(TimeDayOfWeek(tGMT)==DayOfWeek()+1) hrGMT=24+hrGMT; 
     
    double diff = (double)(hrBRK-hrGMT); 
    //diff=(int)diff/3600; Print("diff/3600):",diff);
    if(oddnum) diff=diff+0.5;
 
   _BrokerGMToffSet=diff; //(double)(brkHr-gmtHr);
   _LocalGMToffSet= (double)(-TimeGMTOffset()/3600);
   
    if(!GlobalVariableCheck("xm7_BrokerGMToffSet") || 
       TimeToStr(GlobalVariableTime("xm7_BrokerGMToffSet"),TIME_DATE)!=TimeToStr(TimeLocal(),TIME_DATE) || 
       GlobalVariableGet("xm7_BrokerGMToffSet")!=_BrokerGMToffSet) {   
             GlobalVariableSet("xm7_LocalGMToffSet",localGMToffSet);
             GlobalVariableSet("xm7_BrokerGMToffSet",brokerGMToffSet);
    }   
   
}

int getGMTFromWeb() {
   string gmt_fromweb=httpGET("http://worldtimeapi.org/api/timezone/greenwich.txt");
   if(gmt_fromweb=="" || StringLen(gmt_fromweb)==0 || StringFind(gmt_fromweb,"unixtime")==-1) return(0);
   string response[],response2[];
   StringToArray(gmt_fromweb,"\n", response);
   
   if(ArraySize(response)==0 || ArraySize(response)<11) 
      StringToArray(gmt_fromweb,"\n", response);
   
   if(ArraySize(response)<11) return(0);
   
   for (int x=0; x<ArraySize(response); x++) {
     if(StringFind(response[x],"unixtime")==-1) continue;
     StringToArray(response[x],":", response2);
     break;
   }
   
   if(ArraySize(response2)<2) return(0);
   
   gmt_fromweb=StringTrimLeft(StringTrimRight(response2[1]));
   
   /* //json string
   gmt_fromweb=StringSubstr(gmt_fromweb,StringFind(gmt_fromweb,"unixtime")+10,StringLen(gmt_fromweb)-StringFind(gmt_fromweb,"unixtime"));
   gmt_fromweb=StringSubstr(gmt_fromweb,0,StringFind(gmt_fromweb,","));
   */
   
   if(StringLen(gmt_fromweb)!=10) return(0);
   return((int)gmt_fromweb);
}

void getArrayOfChartIds(long& chartids[]) {
   long currChart,prevChart=-1;
   int limit=100;
   bool found_ind;
   
   ArrayFree(chartids);

   int n=0;
   while(n<limit)// We have certainly not more than 100 open charts
     {
      found_ind=false;
      if(n==0) { 
            prevChart=ChartFirst();         
            ArrayResize(chartids,n+1);
            chartids[n]=prevChart;   
            n++;
            continue; 
       }
      currChart=ChartNext(prevChart);  
      if(currChart<0) break;          // Have reached the end of the chart list          
      ArrayResize(chartids,n+1);
      chartids[n]=currChart;     
      prevChart=currChart;// let's save the current chart ID for the ChartNext() 
      n++;
     }           
}

bool IsDuplicateMagicNumber() {
  bool result=true;
  string oldmagic,oldchartid;
  
  //check if there is already an entry for this EA in Globals
  for(int x=0; x<GlobalVariablesTotal(); x++) {

        if(StringFind(GlobalVariableName(x),"xm7_ea_chartid")==-1) continue;  
        
        long chart_ID = (long)extractGlobalChartId(GlobalVariableName(x));
        string magic = extractMagicNumber(GlobalVariableName(x));
        
        if(ObjectsTotal(chart_ID,0,OBJ_BUTTON)==0) { oldmagic=magic; oldchartid=(string)chart_ID; continue; }  

        if(magic==_xm7_magicnumber_str) {
              MessageBox("Magic number "+_xm7_magicnumber_str+" is already in use on chart with symbol\n"+
                          ChartSymbol(chart_ID)+".  In order to run the EA on this chart,\n"+
                          "use a different magic number.\n\n"+
                          "If this is not the case then remove any indicator(s)\n"+
                          "that show button(s) and reload the EA.",
                           DisplayTitle,MB_ICONINFORMATION);
              MagicNumber=-1;
              return(false);
              break;
        }        
  }
  
  if(GlobalVariableCheck("xm7_ea_chartid_"+oldmagic+"_"+(string)oldchartid))
     GlobalVariableDel("xm7_ea_chartid_"+oldmagic+"_"+(string)oldchartid);

  return(true);
}

void alerts(string magic,string pips) {
  if (PopUp) Alert("CCFP Basket: "+magic+"  pips :"+ pips+"  Time: "+TimeToStr(timeGMT)); 
  if (Send_Notification) SendNotification("CCFP Basket: "+magic+"  pips:"+ pips+"  Time: "+TimeToStr(timeGMT));
}

bool GlobalVarComment(string& s) {
   string result[]; 
   s="";  
     for(int x=0; x<=GlobalVariablesTotal()-1; x++) {
        if(StringFind(GlobalVariableName(x),"xm7_cmnts_"+_xm7_magicnumber_str)>-1) { 
            StringToArray(GlobalVariableName(x),"_",result);  
            s=result[3];
            return(true);
        }
     }
 return(false); 
}

string extractGlobalChartId(string global) {
   string result[];
   StringToArray(global,"_",result); 
   return(result[4]);   
}

string extractMagicNumber(string global) {
   string result[];
   StringToArray(global,"_",result); 
   return(result[3]);   
}


string BaseSymbolName(string item){
   string list1[] = { "EURUSD","GBPUSD","USDCHF","USDJPY","AUDUSD","USDCAD","EURAUD","EURCHF","EURGBP",
                      "EURJPY","GBPCHF","GBPJPY","AUDCAD","AUDCHF","AUDJPY","AUDNZD","CADCHF","CADJPY",
                      "CHFJPY","EURCAD","EURNZD","NZDCAD","NZDCHF","NZDJPY","NZDUSD","GBPAUD","GBPCAD",
                      "GBPNZD","USDDKK" } ;

    for(int x=0; x<ArraySize(list1); x++)  {
         if(StringFind(item,list1[x])>-1) return(list1[x]);
    }
    
    return("");

}

bool excludeItems(string item,string items) {
   string result[];
   StringToUpper(item);
   StringToUpper(items);
   
   if(StringFind(items,",")==-1) {
      ArrayResize(result,1); result[0]=items;
   } else {
      StringToArray(items,",",result);
   }
   
   for(int x=0; x<ArraySize(result); x++)  {
      if(StringFind(item,result[x])>-1) return(true);
   }  
   
   return(false);
}

void GetPrefixSuffix(string symbol, string& prefx, string& suffx){
     string base=BaseSymbolName(symbol);
     if(base=="") return;
            
     prefx="";  suffx="";
     if(StringLen(base)==StringLen(symbol)) return;
     
     int startSymbol=StringFind(symbol,base); 
     suffx=StringSubstr(symbol,startSymbol+6,StringLen(symbol)-(startSymbol+6));
            
     if(startSymbol==0) return; // no prefix
     prefx=StringSubstr(symbol,0,startSymbol); 

   
}

bool FindValidPairForTrading(string& symb, string& pfx, string& sfx) {

      string list1[] = { "EURUSD","GBPUSD","USDCHF","USDJPY","AUDUSD","USDCAD","EURAUD","EURCHF","EURGBP",
                         "EURJPY","GBPCHF","GBPJPY","AUDCAD","AUDCHF","AUDJPY","AUDNZD","CADCHF","CADJPY",
                         "CHFJPY","EURCAD","EURNZD","NZDCAD","NZDCHF","NZDJPY","NZDUSD","GBPAUD","GBPCAD",
                         "GBPNZD","USDDKK" } ;
      pfx=""; sfx="";
       
      symb="";                  
      
      refreshRates();
                         
      for(int x=0; x<ArraySize(list1); x++) {
            symb=CycleThruSuffixes(list1[x], pfx, sfx);
            refreshRates();
            if(MarketInfo(symb,MODE_BID)>0) return(true);
      }
      
      return(false);
}

string CycleThruSuffixes(string symb_, string& prfx, string& sufx) {
         //Try several suffixes till we get the right one. if not do nothing and continue
         int tries=ArraySize(sufxSymbols); 
         
         prfx=prfxSymbols[0];
         if(prfx=="NULL") prfx="";
         if(prfx=="uscode") prfx="_"; 
         
         refreshRates();
         
         while(tries>0) {
            tries--;
            sufx=sufxSymbols[tries]; 
            if(sufxSymbols[tries]=="NULL") sufx=""; 
            if(sufxSymbols[tries]=="uscore") sufx="_"; 
            SymbolSelect(prfx+symb_+sufx, true);
            if (MarketInfo(prfx+symb_+sufx,MODE_BID)>0) {
                 SetGlobalPrefixSuffixVars(prfx,sufx);
                 GetLotMinMaxDgtz(prfx+symb_+sufx,lot_min,lot_max,dgtz);
                 return(prfx+symb_+sufx);   
             }     
         } 
         return("");
}

void SetGlobalPrefixSuffixVars(string prfx, string sffx) {
            if(prfx=="") prfx="NULL"; 
            if(prfx=="_") prfx="uscore"; 
            if(sffx=="") sffx="NULL"; 
            if(sffx=="_") sffx="uscore";
            GlobalVariableSet("xm7_Prefix_"+prfx,0);
            GlobalVariableSet("xm7_Suffix_"+sffx,0);              
}

 void GetBrokerPrefixSuffixes(string& symbol) {
   int t,n;
   string prfx,prfx_list,sufx,sufx_list; //,symbolsArray[];
   //string foundSymbol;
   bool found,gotSuffix;   
   bool selected = false; // false ==> returns all symbols in MarketWatch whether selected or Not
   const int symbolsCount = SymbolsTotal(selected);
   
   string list1[] = { "EURUSD","GBPUSD","USDCHF","USDJPY","AUDUSD","USDCAD","EURAUD","EURCHF","EURGBP",
                      "EURJPY","GBPCHF","GBPJPY","AUDCAD","AUDCHF","AUDJPY","AUDNZD","CADCHF","CADJPY",
                      "CHFJPY","EURCAD","EURNZD","NZDCAD","NZDCHF","NZDJPY","NZDUSD","GBPAUD","GBPCAD",
                      "GBPNZD","USDDKK" } ;
   
   sufx_list="";
   gotSuffix=false;
   n=0;  t=0; 
   
   for(int x=0; x<ArraySize(list1); x++)                
     {           
         found=false; 
        // for(int x=0; x<ArraySize(list1); x++) {
         for(int i = 0; i < symbolsCount; i++) {
               symbol = SymbolName(i, selected); //if selected=false ==> symbol is taken from the general list
               if(StringFind(symbol,list1[x])==-1) continue; // didn't find symbol list in brokerSymbol
               
               if(SkipBinaryPairs && StringFind(symbol,".bo")>-1) continue;
               
               GetPrefixSuffix(symbol,prfx,sufx);
               prfx=StringTrimLeft(StringTrimRight(prfx));
               sufx=StringTrimLeft(StringTrimRight(sufx));
               if(prfx=="") prfx="NULL";
               if(prfx=="_") prfx="uscore";
               if(sufx=="") sufx="NULL";
               if(sufx=="_") sufx="uscore";               
               
               bool _continue=false;
               if(n>0) {
                     for(int y=0; y<ArraySize(sufxSymbols); y++) {
                        if(sufxSymbols[y]==sufx) { _continue=true; break; }
                     }                     
               }
               
               if(_continue) continue;
               
               // Prefix,  set to global (Only need 1 element)
               if(n==0) { 
                  ArrayResize(prfxSymbols,n+1); // prfxSymbols is global only need 1 element
                  prfxSymbols[n]=prfx;
                  prfx_list=prfx;  
               }               
               
               // Suffix, set to global
               ArrayResize(sufxSymbols,n+1);
               sufxSymbols[n]=sufx;  // sufxSymbols is global      
              
              
               if(n==0) {
                  sufx_list=sufx;
               } else {
                  sufx_list+="_"+sufx;
               } 
               
               n++;
         }
       
       }  

         if(debugInfo) {
            Print(__FUNCTION__+"(): preffx size: ",ArraySize(prfxSymbols),"   suffix size: ",ArraySize(sufxSymbols)," for Magic Number: ",(string)MagicNumber);
            Print(__FUNCTION__+"(): preffx found: ",prfx_list);
            Print(__FUNCTION__+"(): suffix list: ",sufx_list);
         }
}

void GetPrefixSuffixFromGlobals(string& pfx, string& sfx) {
            // Get Suffix and Prefix from globals
            bool pre=false, suf=false; string arry[];
            for(int x=0; x<=GlobalVariablesTotal()-1; x++){
                if(pre && suf) break;
                if(StringFind(GlobalVariableName(x),"xm7_Suffix")>-1) {
                   StringToArray(GlobalVariableName(x),"_",arry);
                   if(arry[2]=="NULL") arry[2]="";
                   if(arry[2]=="uscore") arry[2]="_";
                   sfx=arry[2]; suf=true;      
                   ArrayFree(arry);
                 }
                if(StringFind(GlobalVariableName(x),"xm7_Prefix")>-1) {
                   StringToArray(GlobalVariableName(x),"_",arry);
                   if(arry[2]=="NULL") arry[2]="";
                   if(arry[2]=="uscore") arry[2]="_";
                   pfx=arry[2]; pre=true;      
                   ArrayFree(arry);
                 }        
            }
}

 bool DetectPrefixSuffixFromGlobals() {
            int n=0;
            for(int x=0; x<GlobalVariablesTotal(); x++){
                if(StringFind(GlobalVariableName(x),"xm7_Prefix")>-1) n++;
                if(StringFind(GlobalVariableName(x),"xm7_Suffix")>-1) n++;
                if(n==2) return(true);
            }
            return(false);
 }           

   
void GetLotMinMaxDgtz(string sym,double& min, double& max, int digitz){
  digitz=1; 
 
 refreshRates();
 
  min = MarketInfo(sym,MODE_MINLOT);
  max = MarketInfo(sym,MODE_MAXLOT);
  lot_step = MarketInfo(sym,MODE_LOTSTEP);  
  if (lot_step==0.1) dgtz=1;
  if (lot_step==0.01) dgtz=2;  
}

void runningProfit(double& totalpips_, double& totalprofit_) {     
      double pip_profit=0, totalprice,spread=0;
      int cnt=0,p=1;

      totalpips_=0; totalprofit_=0; totalprice=0;
      
      refreshRates();    
      
      for(int i=0; i<OrdersTotal(); i++){
        if(!OrderSelect(i,SELECT_BY_POS)) continue;
         if(OrderType()>OP_SELL || OrderMagicNumber()!=MagicNumber) continue;
         if(OrderCloseTime()!=0) continue; //Already closed  
                 
         p=1;
         if(MarketInfo(OrderSymbol(),MODE_DIGITS)==3 || MarketInfo(OrderSymbol(),MODE_DIGITS)==5) p=p*10; 

         pip_profit += ((OrderProfit()+ OrderCommission() + OrderSwap())/OrderLots()/MarketInfo(OrderSymbol(), MODE_TICKVALUE))/p;
                       
         totalprofit_ += OrderProfit() + OrderCommission() + OrderSwap(); 
         totalprice += OrderOpenPrice();

     } 

     totalpips_ = NormalizeDouble(pip_profit,1);
     totalprice = NormalizeDouble(totalprice,2); 
}

void ResetButtons() {
      EnableButton(_xm7_ea_chartid,true,"xm77_OpenBasketButton_");
      EnableButton(_xm7_ea_chartid,true,"xm77_ResetButton_");
}      

void OpenBasket(){  
      
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
          OpenTrades();    
      } else {
           Print(TimeToStr(TimeCurrent()),"  Trading is Disabled");
           return;      
      }
      
      if(_OrdersTotal()==0)
            if(ArraySize(_pairs)==0) { 
                  EnableButton(_xm7_ea_chartid,true,"xm77_OpenBasketButton_"); 
                  EnableButton(_xm7_ea_chartid,true,"xm77_ResetButton_");
                  
                 if(!UseVirtualBasket) {
                      rBTrigged_butNoTrades=true; GlobalVariableSet("rBtrigged_butNoTrades"+_xm7_magicnumber_str,(double)timeGMT);
                      if(debugTrades) Print(TimeToStr(TimeCurrent()),"No vTrades were positive, no real basket was formed. Magic Number: ",(string)MagicNumber);                 
                 } 
                  
                 if(UseVirtualBasket) {
                      vBTrigged_butNoTrades=true; GlobalVariableSet("vBtrigged_butNoTrades"+_xm7_magicnumber_str,(double)timeGMT);
                      if(debugTrades) Print(TimeToStr(TimeCurrent()),"No vTrades were positive, no real basket was formed. Magic Number: ",(string)MagicNumber); 
                 }  
            }
      
      if (_OrdersTotal()>0 && !B1Done) {
                  B1Done=true; 
                  SetOpenBasketButtonColors();
                  if(Use_ATR) GetBasketStopTake(_basket_stop_profit,_basket_take_profit);
                  _xm7_currgain=0; GlobalVariableDel("xm7_currgain_"+_xm7_magicnumber_str);
                  _xm7_pipcount=0; GlobalVariableDel("xm7_pipcount_"+_xm7_magicnumber_str);                   
                  _xm7_rBasketOpenHour=timeGMT;  GlobalVariableSet("xm7_rBasketOpenHour_"+_xm7_magicnumber_str,(double)_xm7_rBasketOpenHour);    
      }
}

void CloseBasket() {
      
      if(_OrdersTotal()>0) CloseAllTrades();
      
      if(_OrdersTotal()==0) {
            OpenNow=false;  B1Done=false;
            
            gmt_closeTime=""; 
            
            if(UseVirtualBasket)
                  ArrayFree(_virtualOrders); //resetVirtualBasketVariables

            _xm7_RealBasketClosedHr=timeGMT; _basketisclosed=true;
            GlobalVariableSet("xm7_RealBasketClosedHr_"+_xm7_magicnumber_str,(double)_xm7_RealBasketClosedHr);       
            _basket_stop=-1; GlobalVariableDel("xm7_basket_stop_"+_xm7_magicnumber_str);
            GlobalVariableDel("xm7_basket_settBasketLock_"+_xm7_magicnumber_str);
            _lock_trig=false; GlobalVariableDel("xm7_basket_lock_trig_"+_xm7_magicnumber_str);                                                             
      } 
      
      SetOpenBasketButtonColors();   
}


void CloseAllTrades() {
  bool allclosed = false;
  int Tickets[]; //Fifo   
  
  int count=0;    
// Close orders, includes logic to close fifo
  while (_OrdersTotal()>0) { 

         int totalOrders=OrdersTotal();  
 
         if(AccountLeverage()<=50) { //For now usually brokers with 50 or less use FIFO rules
            PopulateTicketArray(Tickets); //Fifo
            SortTickets(Tickets); //Fifo
            totalOrders=ArraySize(Tickets);  
         }   
         
         if(totalOrders==0) { Print("openOrders was detected as 0, have code checked at function CloseAllTrades()(",__LINE__,")"); return; }
           
         for(int cnt=0;cnt<totalOrders; cnt++) {
             
              if(AccountLeverage()>50) {
                  if(!OrderSelect(cnt,SELECT_BY_POS)) continue;
              } else {
                  if(!OrderSelect(Tickets[cnt], SELECT_BY_TICKET)) continue;
              }
              
              if(OrderMagicNumber()!=MagicNumber) continue;
              if(OrderCloseTime()!=0) continue;
                            
              refreshRates();

              if(OrderType() == OP_BUY) trd=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),0,MediumSeaGreen);
              if(OrderType() == OP_SELL) trd=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),0,DarkOrange);
              if(OrderType()>OP_SELL) trd=OrderDelete(OrderTicket()); //close pending orders
         }

         Sleep(5);
  }

   //This portion is done differently than RemoveGlobals().  In this case we try to keep some of the variables so the user can see them on Display
   int t1=GlobalVariablesTotal();
   while(t1>=0) {        
         if(StringFind(GlobalVariableName(t1),"xm7_ea_chartid_"+_xm7_magicnumber_str+"_"+(string)_xm7_ea_chartid)>-1) { t1--; continue; } // Keep chartid 
         if(StringFind(GlobalVariableName(t1),"xm7_ind_chartid_"+_xm7_magicnumber_str+"_"+(string)_xm7_ind_chartid)>-1) { t1--; continue; } // Keep chartid 
         if(StringFind(GlobalVariableName(t1),"xm7_max_week_gain_"+_xm7_magicnumber_str)>-1) { t1--; continue; }  
         if(StringFind(GlobalVariableName(t1),"xm7_min_week_gain_"+_xm7_magicnumber_str)>-1) { t1--; continue; }
         if(StringFind(GlobalVariableName(t1),"xm7_pipcount_"+_xm7_magicnumber_str)>-1) { t1--; continue; }  
         if(StringFind(GlobalVariableName(t1),"xm7_currgain_"+_xm7_magicnumber_str)>-1) { t1--; continue; }
         if(StringFind(GlobalVariableName(t1),"xm7_cmnts_"+_xm7_magicnumber_str)>-1) { t1--; continue; }           
         if(StringFind(GlobalVariableName(t1),_xm7_magicnumber_str,0)>-1) GlobalVariableDel(GlobalVariableName(t1)); 
         t1--;
    }

}

void PopulateTicketArray(int& s[]) {
   int size=0;
   ArrayFree(s);
   
   for (int x=0; x<OrdersTotal(); x++) {    
      if (!OrderSelect(x,SELECT_BY_POS)) continue;
      if (OrderCloseTime()!=0) continue;
      if (OrderType()>OP_SELL || OrderMagicNumber() != MagicNumber) continue;
      ArrayResize(s,size+1);
      s[size]=OrderTicket();
      size++;         
   }
 
}

void SortTickets(int& tickets[]) {
  int res, _ticket;
  int size = ArraySize(tickets);
  for (int i=0; i < size; i++) {
    for (int j=i+1; j < size; j++) {
      res = Compare(tickets[i], tickets[j]);
      if (res == -1) {
        _ticket = tickets[i];
        tickets[i] = tickets[j];
        tickets[j] = _ticket;        
      }
    }
  } 
}
 
 int Compare(int ticket1, int ticket2) {
      trd=OrderSelect(ticket1, SELECT_BY_TICKET);
      string time1 = TimeToStr(OrderOpenTime());
      trd=OrderSelect(ticket2, SELECT_BY_TICKET);
      string time2 = TimeToStr(OrderOpenTime());
      if (time1 < time2) return(1);
      if (time1 > time2) return(-1);
      return(0);
}


bool FlipExistingTrade(string symbol, int op_type,int magic ,string cmt_str,int z, string _xm7tradecomment,string _basketid) {
      int res,n,_ticketBuy,_ticketSell;
      double newFlipPrice=0,orderClosePrice=0,orderlotz,orderstop=0,ordertake=0,pointzz;
      string  ordercomment,result;
      datetime  _buyOpenTime=0,_sellOpenTime=0;
      
      refreshRates();
      
      n=0; _ticketBuy=-1; _ticketSell=-1;
      for(int x=0; x<OrdersTotal(); x++){  
           if(!OrderSelect(x,SELECT_BY_POS)) continue;  
           if(OrderSymbol()!=symbol || OrderMagicNumber()!=magic || StringFind(OrderComment(),cmt_str)==-1) continue;
           if(OrderType()==op_type) continue; //No need to flip the operations are the same
           if(OrderType()==OP_BUY) { n++; _ticketBuy=OrderTicket(); _buyOpenTime=OrderOpenTime(); }
           if(OrderType()==OP_SELL) { n++; _ticketSell=OrderTicket();  _sellOpenTime=OrderOpenTime();}
      }
      
      if(n==0) return(false);
      
      int firstOrder=-1,_lastOrder=-1;
      if(n==2) { _lastOrder=(_buyOpenTime>_sellOpenTime?_ticketBuy:_ticketSell);
                 firstOrder=(_lastOrder=_ticketBuy?_ticketSell:_ticketBuy); }
      if(n==1) _lastOrder=(_buyOpenTime!=0?_ticketBuy:_ticketSell);
      
      //Get LAST ORDER details
      trd=OrderSelect(_lastOrder,SELECT_BY_TICKET); 
      pointzz=MarketInfo(OrderSymbol(),MODE_POINT);
      if(MarketInfo(OrderSymbol(),MODE_DIGITS)==3 || MarketInfo(OrderSymbol(),MODE_DIGITS)==5) pointzz=pointzz*10;
      orderlotz=OrderLots(); //need this var cause eventually the orderlots will be removed      
      orderstop=0; ordertake=0;
                 
      //Prepare for opening flipped trade and test against any other oper trades
      if((OrderType()==OP_BUY && op_type==OP_SELL) || (OrderType()==OP_SELL && op_type==OP_BUY)) {
                  
            result="flipped";                    
            ordercomment=buildTradeComment(z,_xm7tradecomment,_basketid,result);
                   
            if(op_type==OP_BUY) newFlipPrice=MarketInfo(symbol,MODE_ASK); //prepare price for new hedge trade
            if(op_type==OP_SELL) newFlipPrice=MarketInfo(symbol,MODE_BID);
                                     
            //Setup new SL/TP for new hedge trade
            if(_individualTrades_take_profit>0 || _individualTrades_stop_profit>0){
                if(op_type==OP_BUY){
                   if(_individualTrades_stop_profit>0) orderstop=newFlipPrice-_individualTrades_stop_profit*pointzz;
                   if(_individualTrades_take_profit>0) ordertake=newFlipPrice+_individualTrades_take_profit*pointzz;
                }
                if(op_type==OP_SELL){
                   if(_individualTrades_stop_profit>0) orderstop=newFlipPrice+_individualTrades_stop_profit*pointzz;
                   if(_individualTrades_take_profit>0) ordertake=newFlipPrice-_individualTrades_take_profit*pointzz;
                }
            }
                              
            //if now hedge allowed then close signel open trade other wise close the previos to last open trtade
            if(!AllowHedgeRealTrades) { 
               //prepare to close last order
               if(OrderType()==OP_BUY) orderClosePrice=MarketInfo(symbol,MODE_BID);
               if(OrderType()==OP_SELL) orderClosePrice=MarketInfo(symbol,MODE_ASK);
               
               //Close last order so new flip is opened
               CloseTrade(_lastOrder,orderlotz,orderClosePrice);
            } else {
               if(n==2) { trd=OrderSelect(firstOrder,SELECT_BY_TICKET);
                          if(OrderType()==OP_BUY) orderClosePrice=MarketInfo(symbol,MODE_BID);
                          if(OrderType()==OP_SELL) orderClosePrice=MarketInfo(symbol,MODE_ASK); 
                          CloseTrade(OrderTicket(),orderlotz,orderClosePrice); }//close using firstOrder details
            }      

            res=SendTrade(op_type,symbol,orderlotz,newFlipPrice,orderstop,ordertake,ordercomment);
                     
            return(true);
      }      
                     
      return(false);         
  
}

//The following is to check that only one trade is open for this pair...
bool DoesSymbolHaveOpenTrade(string symbol, int op_type, int magic, string cmt_str, string& result) {
     result="";

     for(int x=0; x<OrdersTotal(); x++){  
           if(!OrderSelect(x,SELECT_BY_POS)) continue;
           if(OrderSymbol()==symbol &&  OrderMagicNumber()==magic && 
              StringFind(OrderComment(),cmt_str)>-1 && OrderType()==op_type) return(true);
     }
    
     result="added";
     return(false); 
}

// check for a hedge of same symbol.
bool ChkHedge(string symbol, int op_type, int magic, string cmt_str, string& _rezult) {    
   for(int x=0; x<OrdersTotal(); x++){  
         if(!OrderSelect(x,SELECT_BY_POS)) continue;  
         if(OrderSymbol()==symbol && OrderType()!=op_type && OrderMagicNumber()==magic && 
            StringFind(OrderComment(),cmt_str)>-1) return(true); 
   }
   
   _rezult="hedge";
   return(false); 
}

bool exitOnFlip(string symbol, int op_type) {
      double orderClosePrice=0;         
      
      refreshRates();
      
      for(int x=0; x<OrdersTotal(); x++){  
             if(!OrderSelect(x,SELECT_BY_POS)) continue;  
             if(OrderSymbol()!=symbol)continue;
             if(OrderType()==op_type) return(false);

             if(OrderType()==OP_BUY) orderClosePrice=MarketInfo(OrderSymbol(),MODE_BID);
             if(OrderType()==OP_SELL) orderClosePrice=MarketInfo(OrderSymbol(),MODE_ASK); 
               
             CloseTrade(OrderTicket(),OrderLots(),orderClosePrice);
                
             return(true);      
      }
      return(false);           
}

//Idea from GVC (DB_CCFP_Diff EA)
int CandleColor(string Pair){
     double BarOpen1=0,BarOpen2=0,BarOpen3=0; //CurrentClose
     double BarClose1=0,BarClose2=0,BarClose3=0;
     int tf1=0,tf2=0,tf3=0;
     ENUM_TIMEFRAMES tf;
     string tfs[],candlecolor_str[];
     
     StringToUpper(CandleColorsTimeFrames);

     if(StringFind(CandleColorsTimeFrames,",")>-1) {
         StringToArray(CandleColorsTimeFrames,",",tfs);
     } else {
         if(CandleColorsTimeFrames!="") {
               ArrayResize(tfs,1);
               tfs[0]=CandleColorsTimeFrames;
         }      
     }    
     
     if(ArraySize(tfs)==0) return(-1);
    
     ArrayResize(candlecolor_str,ArraySize(tfs));
     
     string debug_str="3CandleColor for "+Pair+": "; 
     
     if(_OrdersTotal()>0) debug_str="3CandleColor for "+Pair+"(looking for new trade): ";
     
     refreshRates();
     
     int n=0;      
     for (int x=0; x<ArraySize(tfs); x++) {
     
         refreshRates();
         
         candlecolor_str[x]="nocolor";
         tf=GetTimeFrameInt(tfs[x]);
         BarOpen1=iOpen(Pair,tf,0);
         BarClose1=MarketInfo(Pair,MODE_BID);  //BarClose1=iClose(Pair,tf,0);
         if(BarClose1>BarOpen1) { candlecolor_str[x]="Green"; n++; }
         if(BarClose1<BarOpen1) { candlecolor_str[x]="Red"; n--; }
         if(debugFilter) Print(__LINE__," ",debug_str+" "+tfs[x]+"(",tf,") - "+candlecolor_str[x]+"  open: ",BarOpen1,"  close: ",BarClose1);
     } 
     if(debugFilter) Print("");             

     if(n==ArraySize(tfs)) return(OP_BUY);
     if(n==-ArraySize(tfs)) return(OP_SELL);    
  
     return(-1);
}

ENUM_TIMEFRAMES GetTimeFrameInt(string TimeFrameStr) { 
                  if(TimeFrameStr=="M1") return(PERIOD_D1);
                  if(TimeFrameStr=="M5") return(PERIOD_M5);
                  if(TimeFrameStr=="M15") return(PERIOD_M15);
                  if(TimeFrameStr=="M30") return(PERIOD_M30);
                  if(TimeFrameStr=="H1") return(PERIOD_H1);
                  if(TimeFrameStr=="H4") return(PERIOD_H4);
                  if(TimeFrameStr=="D1") return(PERIOD_D1);
                  if(TimeFrameStr=="W1") return(PERIOD_W1);
                  if(TimeFrameStr=="MN1") return(PERIOD_MN1);
                  return(PERIOD_CURRENT);
}

int bbsqueeze(string Pair) { 
   int bolPrd=20,keltPrd=20, momPrd=12, shift;
   double bolDev=2.0,keltFactor=1.5;
   double upB[],loB[],upK[],loK[];
   double diff,d,std,bbs;
   ArrayResize(upB,2); ArrayResize(loB,2); ArrayResize(upK,2); ArrayResize(loK,2);

   double SMA2=iMA(Pair,BBSqueezeTF,2,0,MODE_SMA,PRICE_CLOSE,0);
       
   for(shift=1;shift>=0;shift--) {
      d=LinearRegressionValue(Pair,bolPrd,shift);
        
        if(d>0) {
         upB[shift]=d; loB[shift]=0;
        } else {
         upB[shift]=0; loB[shift]=d;
        }
        
      diff=iATR(Pair,BBSqueezeTF,keltPrd,1)*keltFactor;
      
      int t=5;  //try 6 times to get ATR
      if(diff==0) while(t!=0) {  diff=iATR(Pair,BBSqueezeTF,keltPrd,1)*keltFactor; if(diff!=0) break; t--; }
      
      if(diff==0) return(-1);
      
      std=iStdDev(Pair,BBSqueezeTF,bolPrd,MODE_SMA,0,PRICE_CLOSE,1);
      
      bbs=bolDev * std/diff; 
      
      if(bbs<1) {
         upK[shift]=0; loK[shift]=EMPTY_VALUE;
      } else  {
         loK[shift]=0; upK[shift]=EMPTY_VALUE;
      }
    }  
   
   //indexes: upB=0  loB=1  upK=2  loK=3
   //if loK[0] is !EMPTY_VALUE we have a blue dot (which is good to go) 
   
   if(upB[0]>upB[1] && loK[0]!=EMPTY_VALUE && iClose(Pair,BBSqueezeTF,0)>SMA2) return(OP_BUY);    
   if(loB[0]<loB[1] && loK[0]!=EMPTY_VALUE && iClose(Pair,BBSqueezeTF,0)<SMA2) return(OP_SELL);
        
 return(-1);       
   
}

 double LinearRegressionValue(string _pair, int Len,int shift)
  {
   double SumBars=0,SumSqrBars=0,SumY=0,Sum1=0,Sum2=0,Slope=0;
//----
   SumBars=Len * (Len-1) * 0.5;
   SumSqrBars=(Len - 1) * Len * (2 * Len - 1)/6;
//----
   for(int x=0; x<=Len-1;x++)
     {
      double HH= iLow(_pair,BBSqueezeTF,x+shift);
      double LL= iHigh(_pair,BBSqueezeTF,x+shift);
      for(int y=x; y<=(x+Len)-1; y++)
        {
         HH=MathMax(HH, iHigh(_pair,BBSqueezeTF,y+shift));
         LL=MathMin(LL, iLow(_pair,BBSqueezeTF,y+shift));
        }
      Sum1+=x* (iClose(_pair,BBSqueezeTF,x+shift)-((HH+LL)/2 + iMA(_pair,BBSqueezeTF,Len,0,MODE_EMA,PRICE_CLOSE,x+shift))/2);
      SumY+=(iClose(_pair,BBSqueezeTF,x+shift)-((HH+LL)/2 + iMA(_pair,BBSqueezeTF,Len,0,MODE_EMA,PRICE_CLOSE,x+shift))/2);
     }
   Sum2=SumBars * SumY;
   double Num1=Len * Sum1 - Sum2;
   double Num2=SumBars * SumBars-Len * SumSqrBars;
//----
   if (Num2!=0.0)
     {
      Slope=Num1/Num2;
      } 
         else 
      {
      Slope=0;
     }
   double Intercept=(SumY - Slope*SumBars) /Len;
   double LinearRegValue=Intercept+Slope * (Len - 1);
   return(LinearRegValue);
  }
 
int GetBasketCount(long chartid){ //Count number of baskets/lists on chart from streng indictor
    string objName,objDescript;
    int BasketCount=0,t1=ObjectsTotal(chartid)-1;
   
    if(IsTesting()) return(1);
   
    while(t1>=0) { 
      objName=ObjectName(chartid,t1); objDescript=ObjectGetString(chartid,objName,OBJPROP_TEXT); // Print(objName,"  ",objDescript);
      if ((StringFind(objName,"Signals_TITLE")>-1) ||  //for generic indicatorsCMSM
          (StringFind(objName,"CMSM")>-1 && StringFind(objDescript,"Currency Momentum Strength Meter")>-1) ||  //CMSM
          (StringFind(objName,"CCF_diffsug")>-1 && StringFind(objDescript,"Suggestion for")>-1) || // ccfp-diff
          (StringFind(objName,"CCFdiff_title")>-1 && StringFind(objDescript,"FxM diff")>-1) //FxMadness 
         ) BasketCount++;
      t1--;
    }  //Print("BasketCount : ",BasketCount);
    return(BasketCount);
}

void SeperateOpenClose(datetime gmTime,string& open,string& close) {

   string currentOpen,currentClose,priorOpen,lastClose;
   open=""; close="";
 
   //Get user's discrete open hour
   for(int x=0; x<ArraySize(discreteOpen); x++) {  

         currentOpen=TimeToStr(gmTime,TIME_DATE)+" "+discreteOpen[x];
         
         if(ArraySize(discreteClose)>0) {
               currentClose=TimeToStr(gmTime,TIME_DATE)+" "+discreteClose[x];
               lastClose=TimeToStr(gmTime,TIME_DATE)+" "+discreteClose[ArraySize(discreteClose)-1]; 
                if(gmTime<=StringToTime(currentClose) && gmTime>StringToTime(currentOpen)) {  
                        open=discreteOpen[x]; if(ArraySize(discreteClose)>0) close=discreteClose[x]; break;
                }
         } 
         
         if(x==0 && gmTime<=StringToTime(currentOpen)) { open=discreteOpen[0]; if(ArraySize(discreteClose)>0) close=discreteClose[0]; break; }
         
         if(x==0 && ArraySize(discreteClose)>0 && gmTime<=StringToTime(currentClose)) { open=discreteOpen[0]; if(ArraySize(discreteClose)>0) close=discreteClose[0]; break; } 

         if(x==ArraySize(discreteOpen)-1 && (gmTime>StringToTime(currentOpen) || (ArraySize(discreteClose)>0 && gmTime>StringToTime(currentClose)))) { open=discreteOpen[0]; if(ArraySize(discreteClose)>0) close=discreteClose[0]; break; }
      
         if(x>0){
               priorOpen=TimeToStr(gmTime,TIME_DATE)+" "+discreteOpen[x-1]; 
               if(gmTime>StringToTime(priorOpen) && gmTime<=StringToTime(currentOpen))
                      { open=discreteOpen[x]; if(ArraySize(discreteClose)>0) close=discreteClose[x]; break; }
         } 
   }

} 

void GetGlobalValues() {
      
   string comment_;
   xm7_comments=" === Notes === ";
   if(GlobalVarComment(comment_)) xm7_comments=comment_;
   
   if(GlobalVariableCheck("xm7_max_week_gain_"+_xm7_magicnumber_str)) 
      _xm7_max_week_gain=GlobalVariableGet("xm7_max_week_gain_"+_xm7_magicnumber_str);
      
    if(GlobalVariableCheck("xm7_min_week_gain_"+_xm7_magicnumber_str)) 
      _xm7_min_week_gain=GlobalVariableGet("xm7_min_week_gain_"+_xm7_magicnumber_str);
  
   if(GlobalVariableCheck("xm7_pipcount_"+_xm7_magicnumber_str)) 
      pipsGain=DoubleToStr(GlobalVariableGet("xm7_pipcount_"+_xm7_magicnumber_str),1);
      
   if(GlobalVariableCheck("xm7_maxtime_"+_xm7_magicnumber_str))
       _xm7_maxTime = TimeToStr((datetime)GlobalVariableGet("xm7_maxtime_"+_xm7_magicnumber_str));         

   if(GlobalVariableCheck("xm7_mintime_"+_xm7_magicnumber_str))
       _xm7_minTime = TimeToStr((datetime)GlobalVariableGet("xm7_mintime_"+_xm7_magicnumber_str));     
      
   if(GlobalVariableCheck("xm7_currgain_"+_xm7_magicnumber_str)) 
      currentGain=DoubleToStr(GlobalVariableGet("xm7_currgain_"+_xm7_magicnumber_str),2);

   if(GlobalVariableCheck("xm7_basket_lock_trig_"+_xm7_magicnumber_str))
      _lock_trig=(bool)GlobalVariableGet("xm7_basket_lock_trig_"+_xm7_magicnumber_str);
         
   if(GlobalVariableCheck("xm7_vTriggerHigh_"+_xm7_magicnumber_str)) vTriggerHigh=true; 
   if(GlobalVariableCheck("xm7_vTriggerLow_"+_xm7_magicnumber_str)) vTriggerLow=true;
         
   if (GlobalVariableCheck("xm7_vBasketTriggerHour_"+_xm7_magicnumber_str)) 
        _xm7_vBasketTriggeredHour=(int)GlobalVariableGet("xm7_vBasketTriggerHour_"+_xm7_magicnumber_str);
        
   if(GlobalVariableCheck("rBtrigged_butNoTrades"+_xm7_magicnumber_str))
       rBTrigged_butNoTrades=true;        
        
   if(GlobalVariableCheck("vBtrigged_butNoTrades"+_xm7_magicnumber_str))
       vBTrigged_butNoTrades=true;
               
   if (GlobalVariableCheck("xm7_rBasketOpenHour_"+_xm7_magicnumber_str)) 
        _xm7_rBasketOpenHour=(int)GlobalVariableGet("xm7_rBasketOpenHour_"+_xm7_magicnumber_str); 
        
   if(GlobalVariableCheck("xm7_RealBasketClosedHr_"+_xm7_magicnumber_str))     
        _xm7_RealBasketClosedHr=(int)GlobalVariableGet("xm7_RealBasketClosedHr_"+_xm7_magicnumber_str);

   if(SetPipLevelForAlerts!=0)
      if(GlobalVariableCheck("xm7_AlertSent_"+_xm7_magicnumber_str)) AlertSent=true;

   if(LogData)
         for(int x=0; x<GlobalVariablesTotal(); x++){
             if(StringFind(GlobalVariableName(x),"xm7_CcfpLog_")>-1 && StringFind(GlobalVariableName(x),"_"+_xm7_magicnumber_str)>-1) {
                 int c=0, pos=0;
                 for (int i=0; i<StringLen(GlobalVariableName(x)); i++) {
                     if(StringFind(GlobalVariableName(x),"_",pos)>-1) {
                           pos=StringFind(GlobalVariableName(x),"_",pos)+1;
                           c++;
                     }
                     if(c==4) break;
                 }
                 pos--;
                 LogFileName=StringSubstr(GlobalVariableName(x),0,pos)+".csv"; break;
             }            
         } 
            
   if(continueProcessingVB)
      if(GlobalVariableCheck("xm7_continueVBMonitor_"+_xm7_magicnumber_str))
         _continueVBMonitor=true;                                         
}

void GetDiscreteHourMin(int& h,int& m,int& h_cls,int& m_cls) {
       string hours[];
       h=0; m=0;
       StringToArray(user_openTimeStr,":",hours);
       h=(int)hours[0]; m=(int)hours[1];
       if(user_closeTimeStr!="") {
          ArrayFree(hours);
          StringToArray(user_closeTimeStr,":",hours);
          h_cls=(int)hours[0]; m_cls=(int)hours[1];
       }
}

bool ProcessOtherFilterConditions(dynArray& tmpPairs[]) {  
           string id,id_string,BaseSymbol="",filter_list="",cmd_str,detectedSymbols;
           bool reverse,PairListEmpty=false,flag;
           int bbsqueeze_signal,candle_signals,size=1,n=0;
           dynArray _temp[1];
                      
           //Handle user choice to allow duplicates/hedges across several TradeList suggestions
           if((!AllowDuplicates || !AllowOpposites) && tradeListOnChart>1) {
                 size=1;
                 
                 //test for Duplicates
                 if(!AllowDuplicates) {
                    detectedSymbols="";
                    for(int x=0; x<ArraySize(tmpPairs); x++){   
                          flag=false;
                          
                          for(int y=0; y<ArraySize(_temp); y++){   
                              if(tmpPairs[x].symbol==_temp[y].symbol && tmpPairs[x].optype==tmpPairs[y].optype) {
                                 detectedSymbols+=tmpPairs[x].symbol+","; flag=true; break; //true means dont't keep 
                              }
                          }
                          
                          if(!flag)  {
                               _temp[size-1].symbol=tmpPairs[x].symbol; _temp[size-1].optype=tmpPairs[x].optype;
                               _temp[size-1].basketid=tmpPairs[x].basketid; _temp[size-1].strength=tmpPairs[x].strength;
                               _temp[size-1].buysellcnt=tmpPairs[x].buysellcnt;  _temp[size-1].vprice=tmpPairs[x].vprice;
                               _temp[size-1].vprofit=tmpPairs[x].vprofit;                       
                               size++;
                               ArrayResize(_temp,size);
                          }
                    }
                    
                    ArrayResize(_temp,size-1);
                    if(ArraySize(_temp)>0) {
                         ArrayCopyDynamic(tmpPairs,_temp); 
                    } else {
                         ArrayFree(tmpPairs);
                    }
                    
                    if(detectedSymbols!="" && debugFilter) {
                        detectedSymbols=StringSubstr(detectedSymbols,0,StringLen(detectedSymbols)-1);
                        Print("MagicNumber: ",(string)MagicNumber,"  Pairs(from indicator list) found with Duplicates  :",detectedSymbols);
                     }   
                    
                    if(detectedSymbols!="" && removeALLDuplicates) {
                        n=0; 
                        ArrayFree(_temp);              
                        for(int x=0; x<ArraySize(tmpPairs); x++){ 
                              if(StringFind(detectedSymbols,tmpPairs[x].symbol)>-1) continue;
                                    ArrayResize(_temp,n+1);
                                     _temp[n].symbol=tmpPairs[x].symbol; _temp[n].optype=tmpPairs[x].optype;
                                     _temp[n].basketid=tmpPairs[x].basketid; _temp[n].strength=tmpPairs[x].strength;
                                     _temp[n].buysellcnt=tmpPairs[x].buysellcnt;  _temp[n].vprice=tmpPairs[x].vprice;
                                     _temp[n].vprofit=tmpPairs[x].vprofit;
                                     n++;                                      
                        }
                        if(ArraySize(_temp)>0) {
                             ArrayCopyDynamic(tmpPairs,_temp);
                        } else {
                             ArrayFree(tmpPairs);
                        }                                      
                    }                       
                 }
           
                 //test for opposites (or hedges)                    
                 if(!AllowOpposites){
                      ArrayFree(_temp);
                      size=1;
                      ArrayResize(_temp,1);                 
                      detectedSymbols="";
                      for(int x=0; x<ArraySize(tmpPairs); x++){   
                            flag=false;
                             
                            for(int y=0; y<ArraySize(_temp); y++){   
                                if(tmpPairs[x].symbol==_temp[y].symbol && tmpPairs[x].optype!=tmpPairs[y].optype) {
                                   detectedSymbols+=tmpPairs[x].symbol+","; flag=true; break; //true means dont't keep 
                                }                                
                            }
                             
                            if(!flag)  {
                                 _temp[size-1].symbol=tmpPairs[x].symbol; _temp[size-1].optype=tmpPairs[x].optype;
                                 _temp[size-1].basketid=tmpPairs[x].basketid; _temp[size-1].strength=tmpPairs[x].strength;
                                 _temp[size-1].buysellcnt=tmpPairs[x].buysellcnt;  _temp[size-1].vprice=tmpPairs[x].vprice;
                                 _temp[size-1].vprofit=tmpPairs[x].vprofit;                       
                                 size++;
                                 ArrayResize(_temp,size);
                             }
                      }
                     
                      ArrayResize(_temp,size-1);
                      if(ArraySize(_temp)>0) {
                           ArrayCopyDynamic(tmpPairs,_temp); 
                      } else {
                           ArrayFree(tmpPairs);
                      }
                                          
                      
                      if(detectedSymbols!="" && debugFilter) {
                         detectedSymbols=StringSubstr(detectedSymbols,0,StringLen(detectedSymbols)-1);
                         Print("Magic Number: ",(string)MagicNumber,"   Pairs(from indicator list) found with Opposite/Hedges  :",detectedSymbols);
                      }   
                      
                      //remove detected symbols
                    if(detectedSymbols!="" ||  AccountLeverage()<=50) {
                        n=0;
                        ArrayFree(_temp);
                        for(int x=0; x<ArraySize(tmpPairs); x++){ 
                              if(StringFind(detectedSymbols,tmpPairs[x].symbol)==-1)  { 
                                    ArrayResize(_temp,n+1);
                                     _temp[n].symbol=tmpPairs[x].symbol; _temp[n].optype=tmpPairs[x].optype;
                                     _temp[n].basketid=tmpPairs[x].basketid; _temp[n].strength=tmpPairs[x].strength;
                                     _temp[n].buysellcnt=tmpPairs[x].buysellcnt;  _temp[n].vprice=tmpPairs[x].vprice;
                                     _temp[n].vprofit=tmpPairs[x].vprofit;
                                     n++;                                      
                              }
                        }   
                        if(ArraySize(_temp)>0) {
                              ArrayCopyDynamic(tmpPairs,_temp); 
                         } else {
                              ArrayFree(tmpPairs);
                         }
                                            
                     }                       
                               
                 }
           
           }
         
           if(ReverseSignals==ReverseFromFxMadnessIndicator) { //FXMadness allows users to change direction of trade on list real time
                  for(int x=0; x<ArraySize(tmpPairs); x++){
                  
                         if(StringLen(tmpPairs[x].symbol)==0) continue;  
                                            
                         int t1=ObjectsTotal(_xm7_ind_chartid)-1;
                         id=tmpPairs[x].basketid+id_string;
                         reverse=false;
                  
                         while(t1>=0) {                
                            if (StringFind(ObjectName(_xm7_ind_chartid,t1),id)>-1 && StringFind(ObjectName(_xm7_ind_chartid,t1),"rev")>-1 && 
                                StringFind(ObjectName(_xm7_ind_chartid,t1),"revinf")==-1 && StringFind(ObjectName(_xm7_ind_chartid,t1),"revlog")==-1){ 
                                BaseSymbol=BaseSymbolName(ObjectName(_xm7_ind_chartid,t1)); //Get base symbol from Object Name
                                   if(StringFind(tmpPairs[x].symbol,BaseSymbol)>-1) { //Compare from symbol with symbol array 
                                       if(tmpPairs[x].optype==OP_BUY) { 
                                          tmpPairs[x].optype=OP_SELL;
                                       } else if(tmpPairs[x].optype==OP_SELL) { 
                                           tmpPairs[x].optype=OP_BUY;
                                       }  
                                       t1--; continue;
                                   }
                             }
                             t1--;
                          }       

                   }           
           }     
                 
           //Handle user filters 
           if(TestCandleColors || UseBBSqueeze) {
                 
                 cc_filter_fail=false; bbsq_filter_fail=false;
                 
                 ArrayFree(_temp);
                 size=1;
                 ArrayResize(_temp,1);
                 
                 for(int x=0; x<ArraySize(tmpPairs); x++){

                       flag=false;
                       
                       for(int y=0; y<ArraySize(_temp); y++){   
                           if(TestCandleColors) {
                               candle_signals=-1;
                               candle_signals=CandleColor(tmpPairs[x].symbol);
                               if(candle_signals==-1) { flag=true; cc_filter_fail=true; break; }
                               if(candle_signals==OP_SELL && tmpPairs[x].optype==OP_BUY)  { flag=true; cc_filter_fail=true;  break; }
                               if(candle_signals==OP_BUY && tmpPairs[x].optype==OP_SELL)  { flag=true; cc_filter_fail=true;  break; }
                            }
                            
                            if(UseBBSqueeze) {
                               bbsqueeze_signal=-1;
                               bbsqueeze_signal=bbsqueeze(tmpPairs[x].symbol); 
                               if(bbsqueeze_signal==-1) {  flag=true; bbsq_filter_fail=true;  break; }
                               if(bbsqueeze_signal==OP_BUY && tmpPairs[x].buysellcnt==OP_SELL) {  flag=true; bbsq_filter_fail=true;   break; }
                               if(bbsqueeze_signal==OP_SELL && tmpPairs[x].buysellcnt==OP_BUY) {  flag=true; bbsq_filter_fail=true;   break; }
                            }                            
                                                           
                       }

                       if(!flag)  {
                            _temp[size-1].symbol=tmpPairs[x].symbol; _temp[size-1].optype=tmpPairs[x].optype;
                            _temp[size-1].basketid=tmpPairs[x].basketid; _temp[size-1].strength=tmpPairs[x].strength;
                            _temp[size-1].buysellcnt=tmpPairs[x].buysellcnt;  _temp[size-1].vprice=tmpPairs[x].vprice;
                            _temp[size-1].vprofit=tmpPairs[x].vprofit;                       
                            size++;         
                        }
                 }
                 
                 ArrayResize(_temp,size);
                 if(ArraySize(_temp)>0) {
                       ArrayCopyDynamic(tmpPairs,_temp); 
                 } else {
                       ArrayFree(tmpPairs);
                  }
                                                                     
           }

           if(debugFilter)  
                 if(ArraySize(tmpPairs)==0) { 
                        if(cc_filter_fail && TestCandleColors) {
                              Print(__FUNCTION__+"(): === All Trades fail CandleColor filter (",(string)MagicNumber,")");
                        } else if(bbsq_filter_fail && UseBBSqueeze) {
                              Print(__FUNCTION__+"(): === All Trades fail BBSqueeze filter.  (",(string)MagicNumber,")");
                        } else if(cc_filter_fail && TestCandleColors && bbsq_filter_fail && UseBBSqueeze){
                              Print(__FUNCTION__+"(): === All Trades failed both filters. (",(string)MagicNumber,")");  
                        }
                        
                        return(false);
                                                  
                 } else { 
                        Print(" ==== ",__FUNCTION__,"(): EA processed list:  (",(string)MagicNumber,")======");
                        if(_OrdersTotal()>0) Print(" ==== (looking for new trades to add to basket) ====");   
                        for(int x=0; x<ArraySize(tmpPairs); x++){
                              if((int)tmpPairs[x].optype==OP_BUY) cmd_str="Buy";
                              if((int)tmpPairs[x].optype==OP_SELL) cmd_str="Sell";
                              if(tmpPairs[x].symbol!="") { Print(x,"  ",tmpPairs[x].symbol+" ",cmd_str,"   ID: ",tmpPairs[x].basketid,"  strength_pos: ",(string)tmpPairs[x].strength); }
                        }
                        if(_OrdersTotal()>0) Print(" ==== (looking for new trades to add to basket) ====");
                        Print(" ==== ",__FUNCTION__,"(): EA processed list: ======"); 
                }
     
  
    return(true);          
}

void resetAllVariables() {                      
         pipsGain="0";  currentGain="0"; daysGain="0"; weeksGain="0"; monthGain="0"; yearGain="0";
         total_pips=0; total_profit=0; _basketisclosed=false; cc_filter_fail=false; bbsq_filter_fail=false;
         rBTrigged_butNoTrades=false; GlobalVariableDel("rBtrigged_butNoTrades"+_xm7_magicnumber_str);       
         AlertSent=false; GlobalVariableDel("xm7_AlertSent_"+_xm7_magicnumber_str);
         _xm7_max_week_gain=0; GlobalVariableSet("xm7_max_week_gain_"+_xm7_magicnumber_str,0);
         _xm7_min_week_gain=0; GlobalVariableSet("xm7_min_week_gain_"+_xm7_magicnumber_str,0);
         _xm7_maxTime=""; GlobalVariableDel("xm7_maxtime_"+_xm7_magicnumber_str);
         _xm7_minTime=""; GlobalVariableDel("xm7_mintime_"+_xm7_magicnumber_str);
         _xm7_rBasketOpenHour=0; GlobalVariableDel("xm7_rBasketOpenHour_"+_xm7_magicnumber_str);            
         _basket_stop=-1; GlobalVariableDel("xm7_basket_stop_"+_xm7_magicnumber_str);
         GlobalVariableDel("xm7_basket_settBasketLock_"+_xm7_magicnumber_str);
         _lock_trig=false; GlobalVariableDel("xm7_basket_lock_trig_"+_xm7_magicnumber_str);   
         resetVirtualBasketVariables();
} 

void resetVirtualBasketVariables() {
           RemoveObjects("xm7_virtual");
           RemoveObjects("Virtual"); // removes teh open virt button
           cc_filter_fail=false; bbsq_filter_fail=false;
           FileDelete("virtualOrders_"+_xm7_magicnumber_str);
           ArrayFree(_virtualOrders); _virtualbasketclosedTime=0;
           vBTrigged_butNoTrades=false; GlobalVariableDel("vBtrigged_butNoTrades"+_xm7_magicnumber_str);
           virtual_profit=0;
           virtual_trades_list="";
           vTriggerHigh=false; GlobalVariableDel("xm7_vTriggerHigh_"+_xm7_magicnumber_str);
           vTriggerLow=false; GlobalVariableDel("xm7_vTriggerHigh_"+_xm7_magicnumber_str);
           vHighest_pips=0; GlobalVariableDel("xm7_vHighPip_"+_xm7_magicnumber_str);
           vLowest_Pips=0; GlobalVariableDel("xm7_vLowPip_"+_xm7_magicnumber_str);
           vMaxTime=""; GlobalVariableDel("xm7_maxVtime_"+_xm7_magicnumber_str);
           vMinTime=""; GlobalVariableDel("xm7_minVtime_"+_xm7_magicnumber_str);
           _xm7_vBasketTriggeredHour=0; GlobalVariableDel("xm7_vBasketTriggerHour_"+_xm7_magicnumber_str);
           _continueVBMonitor=false; GlobalVariableDel("xm7_continueVBMonitor_"+_xm7_magicnumber_str);          
}


void buttonActive_resetAllVariables() {                      
         /*pipsGain="0";  currentGain="0"; daysGain="0"; weeksGain="0"; monthGain="0"; yearGain="0";
         total_pips=0; total_profit=0; 
         _xm7_max_week_gain=0; GlobalVariableSet("xm7_max_week_gain_"+_xm7_magicnumber_str,0);
         _xm7_min_week_gain=0; GlobalVariableSet("xm7_min_week_gain_"+_xm7_magicnumber_str,0);
         _xm7_maxTime=""; GlobalVariableDel("xm7_maxtime_"+_xm7_magicnumber_str);
         _xm7_minTime=""; GlobalVariableDel("xm7_mintime_"+_xm7_magicnumber_str);*/

         _basketisclosed=false; cc_filter_fail=false; bbsq_filter_fail=false;
         rBTrigged_butNoTrades=false; GlobalVariableDel("rBtrigged_butNoTrades"+_xm7_magicnumber_str);       
         AlertSent=false; GlobalVariableDel("xm7_AlertSent_"+_xm7_magicnumber_str);
         _xm7_rBasketOpenHour=0; GlobalVariableDel("xm7_rBasketOpenHour_"+_xm7_magicnumber_str);            
         _basket_stop=-1; GlobalVariableDel("xm7_basket_stop_"+_xm7_magicnumber_str);
         GlobalVariableDel("xm7_basket_settBasketLock_"+_xm7_magicnumber_str);
         _lock_trig=false; GlobalVariableDel("xm7_basket_lock_trig_"+_xm7_magicnumber_str); 
         
          resetVirtualBasketVariables();  

} 

bool SetEventTimer(int time) {
   int error = - 1 ; 
   int counter = 0 ; 
   do
   { 
      ResetLastError (); 
      EventSetTimer (time); 
      error = GetLastError (); 
      if (error!=0) Sleep  (1000); 
      counter ++; 
      if(counter>100) break; 
   } 
   while (error!=0 && !IsStopped ());
   
   if( error!=0) {  
         MessageBox("Failed to start Timer(). Please Reload EA and try again.\n\nIf this continues have code checked.","xm7_TradeMonitor",MB_ICONEXCLAMATION); 
         return(false); 
   } else {
         if(debugTime) Print("EA Timer() has started and is set to "+(string)time+" s interval. Magic Number: ",(string)MagicNumber);
   }
   
   return(true);
}

void ArrayCopyDynamic(dynArray& d[], dynArray& s[]) {
      
      ArrayFree(d);
      ArrayResize(d,ArraySize(s));
      
      for(int x=0; x<ArraySize(s); x++) {
            d[x].symbol=s[x].symbol; //Symbol
            d[x].basketid=s[x].basketid; //basket_id
            d[x].optype=s[x].optype; //optype
            d[x].buysellcnt=s[x].buysellcnt; //buysel_count           
            d[x].strength=s[x].strength; //strength
            d[x].vprice=s[x].vprice; //vprice
            d[x].vprofit=s[x].vprofit; //vprofit        
      }   
}


void sort_multiDimen_array(double& item[],dynArray& pairs_out[]){
      
   dynArray tmp[];
   ArraySort(item,WHOLE_ARRAY);  //,0,MODE_DESCEND)
  
   for (int x=0; x<ArraySize(item); x++) {  
          for(int y=0; y<ArraySize(_pairs); y++) {
               if(item[x]==_pairs[y].strength){  
                  ArrayResize(tmp,x+1); //init_dynnamicArray(tmp,x+1,2,5);
                  tmp[x].symbol=_pairs[y].symbol; //.col[0]; //Symbol
                  tmp[x].basketid=_pairs[y].basketid; //.col[1]; //basket_id
                  tmp[x].optype=_pairs[y].optype; //.val[0]; //optype
                  tmp[x].buysellcnt=_pairs[y].buysellcnt; //.val[1]; //buysel_count           
                  tmp[x].strength=_pairs[y].strength; //.val[2]; //strength
                  tmp[x].vprice=_pairs[y].vprice; //vprice
                  tmp[x].vprofit=_pairs[y].vprofit; //vprofit                    
                  break;   
               }
          }
   }
      
  //Copy tmp[] to _pairs[];
  for(int y=0; y<ArraySize(tmp); y++) {
      pairs_out[y].symbol=tmp[y].symbol; //.col[0]; //Symbol
      pairs_out[y].basketid=tmp[y].basketid; //.col[1]; //basket_id
      pairs_out[y].optype=tmp[y].optype; //.val[0]; //optype
      pairs_out[y].buysellcnt=tmp[y].buysellcnt; //.val[1]; //buysel_count           
      pairs_out[y].strength=tmp[y].strength; //.val[2]; //strength
      pairs_out[y].vprice=tmp[y].vprice; //vprice
      pairs_out[y].vprofit=tmp[y].vprofit; //vprofit        
         
   }     
}

double getPairStrength(string txt) {
   string result[],result2[];

   StringToArray(txt,"(",result);   
   StringToArray(result[1],",",result2);  
   double n1=StringToDouble(StringTrimLeft(StringTrimRight(result2[0])));   
   
   ArrayFree(result);
   result2[1]=StringTrimLeft(StringTrimRight(result2[1])); 

   StringToArray(result2[1]," ",result);   
   double n2=StringToDouble(StringTrimLeft(StringTrimRight(result[0]))); 
   
   double total=n1+MathAbs(n2);
   
   return(NormalizeDouble(total,2));  
}

void initVariables() {

   //magic number as string  
   _xm7_magicnumber_str=(MagicNumber<10?"0"+(string)MagicNumber:(string)MagicNumber);

   _xm7_ea_chartid=ChartID(); 
   
   tradeListOnChart=GetBasketCount(ChartID()); // get number of lists on chart
  
   if(_Symbol_=="") _Symbol_=Symbol();   

        // Get all broker suffixs/prefixs into arrays, populate _symbol_
   //GetBrokerPrefixSuffixes(_Symbol_);  
   _Symbol_=Symbol();
      //See if we already have valid prefx/sufx in globlas and use
      //if(DetectPrefixSuffixFromGlobals()) { 
       //     GetPrefixSuffixFromGlobals(Prefix,Suffix);
        //} else {
             //FindValidPairForTrading(_Symbol_,Prefix,Suffix);
   GetPrefixSuffix(_Symbol_,Prefix,Suffix); //Get the current Symbol chart prefix and suffixz 
   //SetGlobalPrefixSuffixVars(Prefix,Suffix);
    //}
 
    GetPairs();
  
    CheckInputHours();
   
    if(letEASetNegTrig){
          if(!checkArrayTest(basketNumberOfTrades,"numbers")) ShowTxtMessage("numbers");  
          if(!checkArrayTest(negativeTriggers,"triggers")) ShowTxtMessage("triggers");
    }     
    
    //Get user's discrete open/close hour(s)
    if((StringFind(GMTOpenHour,",")>-1 && StringFind(GMTOpenHour,":")==2) || (StringFind(GMTOpenHour,"-")==5 && StringFind(GMTOpenHour,":")==2))
         StringToArrays(GMTOpenHour,",",discreteOpen,discreteClose);

    DailyStartTime=GMTOpenHour;
    if(ArraySize(discreteOpen)>0) DailyStartTime=discreteOpen[0]; 
    
    gmt_closeTime="";

    setCloseHours();

    //button/text box coordinates
    x_btn=25; y_btn=50;
    btn_width=140; btn_heigth=25;
   
   //prepare the disallowedPairsCurrencies
   disallowPairsCurrencies=StringTrimLeft(StringTrimRight(disallowPairsCurrencies));
   StringToUpper(disallowPairsCurrencies);
   if(disallowPairsCurrencies=="NONE") disallowPairsCurrencies=""; 

   _xm7_IgnoreAllCloseHours=false;
   if(TradeMode==Weekly && (GMTFridayCloseHour=="-" || GMTFridayCloseHour=="")) _xm7_IgnoreAllCloseHours=true;
   if(TradeMode==Daily && (GMTDailyCloseHour=="-" || GMTDailyCloseHour=="")) _xm7_IgnoreAllCloseHours=true;
   if(TradeMode==Monthly) _xm7_IgnoreAllCloseHours=true; 
      
   //variables
   total_pips=0;
   total_profit=0;
   _xm7_maxTime="";
   _xm7_minTime="";
   vMaxTime="";
   vMinTime="";
   _xm7_max_week_gain=0;
   _xm7_min_week_gain=0;
   _xm7_pipcount=0;
   _xm7_currgain=0;
   SkipBinaryPairs=true;
   B1Done=false;
   vTriggerHigh=false;
   vTriggerLow=false;
   discreteOpenHours=false;
   AlertSent=false;
   OpenNow=false;
   OpenVirt=false;
   _basket_take_profit= MathAbs(Take_Profit);
   _basket_stop_profit= MathAbs(Stop_Profit);
   _individualTrades_take_profit= MathAbs(IndividualTrades_Take_Profit);
   _individualTrades_stop_profit=MathAbs(IndividualTrades_Stop_Loss);
   _basket_oneTimeBE_value=beLock;
   _basket_stop=-1;
   _lock_trig=false; 
   _xm7_vBasketTriggeredHour=0;
   _xm7_rBasketOpenHour=0;
   _xm7_RealBasketClosedHr=0;
   vhours=0;
   rhours=0;
   vBTrigged_butNoTrades=false;
   rBTrigged_butNoTrades=false;  
   user_openTimeStr="";
   user_closeTimeStr="";
   _basketisclosed=false;
   _virtualbasketclosedTime=0;
   virtual_profit=0;
   _continueVBMonitor=false;
   minimized_display_panel=false;
   minimized_virtual_panel=false;
   _VirtualUpperTriggerLevel=MathAbs(VirtualUpperTriggerLevel);
   _VirtualLowerTriggerLevel=MathAbs(VirtualLowerTriggerLevel);

   //time 
   IsNewGMTDay();
   IsNewWeek();
   IsNewMonth();
   IsNewGMTDayLog();
   IsNewWeek_gmt();             
}

void ShowMessage(showmsg_type s) {

    switch(s){
             
      case(noBeginLockProfit): 
            MessageBox("Check input setStartLocking.  It must not be 0.\n"+
                       "\n"+
                       "setStartLocking is what tells the EA WHEN to start locking profit.",
                       DisplayTitle,MB_ICONEXCLAMATION); 
      break;
      
      case(lowLockPOP):
            MessageBox("setStartLocking must be greater than LockPercentLevel. Check\n"+
                       "inputs and make sure that setStartLocking has correct value.\n"+
                       "\n"+
                       "setStartLocking is what tells the EA WHEN to start locking profit.",
                       DisplayTitle,MB_ICONEXCLAMATION);      
      break;
      
      case(lowLockManual):
            MessageBox("setStartLocking must be greater than 'One Time BE Lock'. Check\n"+
                       "inputs and make sure that setStartLocking has correct value.\n"+
                       "\n"+
                       "setStartLocking is what tells the EA WHEN to start locking profit.",
                       DisplayTitle,MB_ICONEXCLAMATION);      
      break;      
                         
   } 
}

void ShowTxtMessage(string s) {            
      StringToLower(s);
      if(s=="incorrect_tf_input") {
            MessageBox("Input to CandleColorsTimeFrames is incorrect. Please check input.\n"+
                       "Correct input should look like the following:\n"+
                       " 'H1,D1,WK1' or 'H4,D1' or 'H1,D1,H4,MN1' ",
                       DisplayTitle,MB_ICONEXCLAMATION); 
      } else if(s=="numbers") {
            MessageBox("Incorrect format for input 'basketNumberOfTrades'. Please check input.\n"+
                       "Correct input should look like the following example:\n"+
                       " '1-6,7-10,11-14,15-Greater' \n"+
                       "If you continue without correcting this the default values will be used: '1-5,6-10,11-14,15-Greater'",
                       DisplayTitle,MB_ICONEXCLAMATION);
             basketNumberOfTrades ="1-5,6-10,11-14,15-Greater";           
      } else if(s=="triggers") {
            MessageBox("Incorrect format for input 'negativeTriggers'. Please check input.\n"+
                       "Correct input should look like the following example:\n"+
                       " '-200,-300,-400,-500' \n"+
                       "If you continue without correcting this the default values will be used: '-150,-250,-350,-450'",
                       DisplayTitle,MB_ICONEXCLAMATION);
            negativeTriggers ="-150,-250,-350,-450";
      } else if(s=="notsamesize") {
            MessageBox("You entered different number of items for the input list of \n"+
                        "'negativeTriggers' and 'basketNumberOfTrades'. Please check and make sure that.\n"+
                       "the number of items separated by the commas, are the same.\n"+
                       "\n"+
                       "If you continue without correcting this the following default values will be used:\n"+
                       "'basketNumberOfTrades' : '1-5,6-10,11-14,15-Greater'\n"+
                       "'negativeTriggers' : '-150,-250,-350,-450'",
                       DisplayTitle,MB_ICONEXCLAMATION);
                       //defaults are set in function that called this message getNegativeTrigger()                 
      } else if(s=="missingindi") {
            MessageBox("The required indicators where not found on any chart.\n"+
                       "Load a strength indicator so the EA can detect the suggested pairs.\n"+
                       "Once you load the indicator, reload the EA.\n"+
                       "Note: EA can detect the following strength Indicators:\n"+
                       "      CCFp-Diffv2.0 (original indicator)\n"+
                       "      CCFp-Diff_[v2.0-MTF]\n"+
                       "      CCFp-Diff v3.01\n"+
                       "      ###CMSMIndVxx.xx",
                       DisplayTitle,MB_ICONEXCLAMATION);       
      } else if(s=="tradeallowed"){
            MessageBox("Live Trading is Disabled\n"+
                       "Make sure that the \"Allow live trading\" checkbox is enabled in the\n"+
                       "Expert Advisor or script properties",
                       DisplayTitle,MB_ICONEXCLAMATION);      
      } else if(s=="dllnotallowed") {
             MessageBox("Allow DLL Imports is Disabled\n"+
                        "Make sure that \"Allow DLL Imports\" checkbox is checked\n"+
                        "in Expert Advisor properties\n"+
                        "To make this permanent:\n Goto Tools==>Options==>Experts Advisors tab\n"+
                        "and click \"Allow DLL Imports\"",
                        DisplayTitle,MB_ICONEXCLAMATION);         
      }  else {
            MessageBox(s,DisplayTitle,MB_ICONEXCLAMATION);
      }
}             

bool checkIfWeekend(){
    if(TimeDayOfWeek(TimeGMT())==6 || (TimeDayOfWeek(TimeGMT())==5 && TimeHour(TimeGMT())>=21 && TimeMinute(TimeGMT())>59) ||
       (TimeDayOfWeek(TimeGMT())==0 && TimeHour(TimeGMT())<22)) return(true);
    
    return(false);      
}       

bool CheckTFString(string c) {
   string TF[] = { "M1","M5","M15","M30","H1","H4","D1","WK1","MN1" } ;
   // M1=PERIOD_M1, M5=PERIOD_M5, M15=PERIOD_M15, H1=PERIOD_H1, H4=PERIOD_H4, D1=PERIOD_D1, WK1=PERIOD_W1, MN1=PERIOD_MN1 
   StringToUpper(c);
   for(int x=0; x<ArraySize(TF); x++) {
      if(StringFind(c,TF[x])==-1) return(false);
   }
   return(true);
}

void CheckInputHours() { 

    int x=0,y=0,z=0;
 
    //Get rid of spaced in strings
    StringReplace(GMTOpenHour," ","");
    StringReplace(GMTDailyCloseHour," ",""); 
    StringReplace(GMTFridayCloseHour," ","");
    
    //Check single open our entry
    if(StringFindCount(GMTOpenHour,",")==0 && StringFindCount(GMTOpenHour,"-")==0)
            if(StringFind(GMTOpenHour,":")!=2 || StringLen(GMTOpenHour)!=5) { 
                    ShowTxtMessage("Please check the format of the GMTOpenHour input\n"+
                                   "You must have the format as 'HH:mm'"); 
                    return;           
            } 
 
    //Check format for single open close
    if(StringFind(GMTOpenHour,":")>-1 && StringFind(GMTOpenHour,"-")>-1 && StringFind(GMTOpenHour,",")==-1) 
            if(StringFind(GMTOpenHour,":")!=2 && StringFind(GMTOpenHour,":")!=2 && StringFind(GMTOpenHour,":")!=8 &&
               StringFind(GMTOpenHour,"-")!=5 && StringLen(GMTOpenHour)!=11) {
                    ShowTxtMessage("Please check the format for the GMTOpenHour input\n"+
                                   "To setup a single open/close hrs use format 'HH:mm-HH2:mm'\n"+
                                   "To setup multiple open/close hrs use format:\n"+
                                   "'HH:mm-HH2:mm,HH:mm-HH2:mm,HH:mm-HH2:mm'"); 
                     return;
            }                       
    
    //Check the open hours and close hour inputs for correct format
    if(StringFind(GMTOpenHour,",")>-1 && StringFind(GMTOpenHour,"-")>-1 && StringFind(GMTOpenHour,":")>-1){
         x=StringFindCount(GMTOpenHour,",");  
         y=StringFindCount(GMTOpenHour,"-");
         z=StringFindCount(GMTOpenHour,":");
         if(x!=y-1 || x>=y || z!=2*y) {  
                    ShowTxtMessage("Please check the format for the GMTOpenHour input\n"+
                                   "To setup a single open/close hrs use format 'HH:mm-HH2:mm'\n"+
                                   "To setup multiple open/close hrs use format:\n"+
                                   "'HH:mm-HH2:mm,HH:mm-HH2:mm,HH:mm-HH2:mm'");
                    return;
         }               
    }
    
    //Check for single hour lists format  h,h2,h3,h4 ...
    if(StringLen(GMTOpenHour)>5 && StringFindCount(GMTOpenHour,",")>=1 && StringFindCount(GMTOpenHour,"-")==0) {
         x=StringFindCount(GMTOpenHour,",");  
         z=StringFindCount(GMTOpenHour,":");
         if(x!=z-1) {  
                    ShowTxtMessage("Please check the format for the GMTOpenHour input\n"+
                                   "To setup a single open/close hrs use format 'HH:mm-HH2:mm'\n"+
                                   "To setup multiple open/close hrs use format:\n"+
                                   "'HH:mm-HH2:mm,HH:mm-HH2:mm,HH:mm-HH2:mm'");
                    return;
         }                  
    }
    
 
    if(StringFind(GMTDailyCloseHour,",")>-1 || (StringLen(GMTDailyCloseHour)>1 && StringFind(GMTDailyCloseHour,":")==-1))  {
         if(StringFind(GMTDailyCloseHour,",")>-1) {
            ShowTxtMessage("OOPs check the 'Daily Hour to Close Basket' input. if you entered multiple hours.\nYou can only have one entry\nEA will use default: 23:50");
         } else {
            ShowTxtMessage("OOPs check the 'Daily Hour to Close Basket' input, incomplete hour entry, you are missing ':'\nEA will use default: 23:50");
         }
         GMTDailyCloseHour="23:50";
         return;
    }
    
    if(StringFind(GMTOpenHour,":")==-1 || StringLen(GMTOpenHour)!=5) {
         ShowTxtMessage("You 'Open Hour' input format was not correct. Check Input, you are missing ':'\nEA will use default: GMTOpenHour 00:00");
         GMTOpenHour="00:00";
         return;
    }
    
    if(StringFind(GMTFridayCloseHour,",")>-1 || (StringLen(GMTFridayCloseHour)>1 && StringFind(GMTFridayCloseHour,":")==-1))  {
         if(StringFind(GMTFridayCloseHour,",")>-1 ) {
            ShowTxtMessage("You 'Friday Close Hour' input format was not correct. Check Input, if you entered multiple hours.\n You can only have one entry\nEA will use default: GMTFridayCloseHour 19:50");
         } else {
            ShowTxtMessage("You 'Friday Close Hour' input format was not correct. Check Input, incomplete hour entry, you are missing ':'\nEA will use default: GMTFridayCloseHour 19:50");
         }   
            GMTDailyCloseHour="19:50";
    }
}

void emergencyCloseAll() { 
   refreshRates();
   for(int x=0; x<OrdersTotal(); x++) {
      if(!OrderSelect(x,SELECT_BY_POS)) continue;
      if(OrderType()==OP_BUYSTOP && OrderMagicNumber()==MagicNumber) {
         double pointz=MarketInfo(OrderSymbol(),MODE_POINT);
         if(MarketInfo(OrderSymbol(),MODE_DIGITS)==3 || MarketInfo(OrderSymbol(),MODE_DIGITS)==5) pointz=pointz*10;      
         if(OrderOpenPrice()-Bid>490*pointz) { trd=OrderDelete(OrderTicket()); CloseBasket(); return; }
      }
   }             
}

bool marginTest(string _symbl, double& _lots) {
      int digitz=1;
      refreshRates();
      if (MarketInfo(_symbl,MODE_LOTSTEP)==0.1) digitz=1;
      if (MarketInfo(_symbl,MODE_LOTSTEP)==0.01) digitz=2;
      double Margin=MarketInfo(_symbl,MODE_MARGINREQUIRED);
      double FreeMargin=AccountFreeMargin();
      double availablelots=NormalizeDouble(FreeMargin/Margin,digitz);
      if(availablelots<MarketInfo(_symbl,MODE_MINLOT)) return(false);
      if(_lots>availablelots) _lots=availablelots;
      return(true);
 }        

double getNegativeTrigger(int openTrades) {
         string numberz[],triggerz[],range[],_basketNumberOfTrades;
         double trigger=0;
   
         _basketNumberOfTrades=StringSubstr(_basketNumberOfTrades,0,StringLen(_basketNumberOfTrades)-8);
                  
         StringToArray(_basketNumberOfTrades,",",numberz);
         StringToArray(negativeTriggers,",",triggerz);
                  
         if(ArraySize(numberz)!=ArraySize(triggerz)) {
               ShowTxtMessage("notSameSize");
               ArrayFree(numberz); ArrayFree(triggerz);
               StringToArray("1-5,6-10,11-14,15",",",numberz);
               StringToArray("-150,-250,-350,-450",",",triggerz);                     
         }
                  
         for(int x=0; x<ArraySize(numberz); x++) {
                if(StringFind(numberz[x],"-")>-1){
                      StringToArray(numberz[x],"-",range);
                      if(openTrades>=(int)range[0] && openTrades<=(int)range[1]) { trigger=(double)triggerz[x]; break; }
                 } else {
                      if(x==ArraySize(numberz)-1 && openTrades>=(int)numberz[x]) { trigger=(double)triggerz[x]; break; }
                 }   
         }
         return(NormalizeDouble(trigger,1));               
} 

bool chkHrMark(double _currentBasketProfit) {
      if(timeGMT-_xm7_rBasketOpenHour>=checkProfitStatusMins*60 && timeGMT-_xm7_rBasketOpenHour<=(checkProfitStatusMins+5)*60) {
            switch(selectMarkOption){
                  case(Check_DD):
                        if(_currentBasketProfit<=0) CloseBasket(); return(true);
                   break;
                           
                   case(Check_DDorProfit):
                         CloseBasket();return(true);
                   break;
             }     
      }
      return(false);               
}

bool chkHrVirtualMark() {
      if(timeGMT-_xm7_vBasketTriggeredHour>=checkProfitStatusMins*60 && timeGMT-_xm7_vBasketTriggeredHour<=(checkProfitStatusMins+5)*60) {       
            ArrayFree(_virtualOrders); 
           _virtualbasketclosedTime=TimeGMT();
           return(true);
      }
      return(false);               
}

bool checkArrayTest (string test, string _type) {
  string _test[];
  
  if(_type=="triggers")
      if(StringFind(test,",")==-1) return(false);

  if(_type=="numbers") {
     StringToLower(test);     
     if(StringFind(test,"1-")!=0 || StringFind(test,"-greater")!=StringLen(test)-8 ||
        StringFind(test,",")==-1 ||  StringFind(test,"-")==-1
       ) return(false);

     StringToArray(test,",",_test);
     for(int x=0; x<ArraySize(_test); x++)
        if(StringFind(_test[x],"-")==-1) return(false);
  }  
   
  return(true);  
   
}

int randomOP() {
      //get random number of symbols to trade
      int result=OP_BUY;
      int number=MathAbs(randomInteger(7,20))+7;
      if(number<7) result=OP_BUY;
      if(number>13) result=OP_SELL;
      return(result);
}
           
int randomInteger(int begin, int end) {
  double randvalue,RAND_MAX=32767.0;
  begin = MathAbs(begin);
  end = MathAbs(end);
  
  randvalue=MathRand()/((RAND_MAX)+1);//generates a psuedo-random double between 0.0 and 0.999..
  
  if(begin>end) return((int)(0+begin*randvalue));
  return((int)(begin + (begin-end)*randvalue)); 
}

//========================================================= Disclaimer Clause =======================================================
//#property description "************** Disclaimer ************"
#property description "The end user/trader of this Expert Advisor (EA) agrees and fully understands that there absolutely"
#property description "no guarantees or representations of any kind written, verbal, or implied that this EA will result"
#property description "in profitable or no-profitable results. The end user/trader agrees to hold no other involved party"
#property description "liable for any incurred damages or losses due to use of this EA. The end user/trader will have no"
#property description "claims direct or indirect against losses/damages that may be incurred."
//#property description "************** Disclaimer ************"