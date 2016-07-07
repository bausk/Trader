//+------------------------------------------------------------------+
//|                                       TestAdvisor_RndScalp01.mq5 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2016 Panzer Korps"
#property version     "0.00"
#property description "This Expert Advisor places the pending orders during the"
#property description "time from StartHour till EndHour on the price levels, that"
#property description "are 1 point below/lower the current trade range."
#property description "The StopLoss levels are placed at the opposite side"
#property description "of the price range. After order execution, the TakeProfit value"
#property description "is set at the 'indicator_TP' level. The StopLoss level is moved"
#property description "to the SMA values only for the profitable orders."

#define EXPERT_MAGIC 123456
//--- input parameters
input int      StopLoss=300;
input int      RunningStopLoss=90;
input int      TakeProfit=300;
input double   LotSafety=40;
input int      BuyCutoff=35;
input int      SellCutoff=75;
input int      OscDiff=30;
input int      CheckSeconds = 3600;

int hMA, hOscSlow, hOscFast, hAwesome;
datetime last_checked;
double position_price;
double latest_checked_price;
double last_processed_time;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   hOscSlow = iStochastic(NULL, 0, 21, 4, 10, MODE_SMA, STO_LOWHIGH);
   hOscFast = iStochastic(NULL, 0, 5, 2, 2, MODE_SMA, STO_LOWHIGH);
   hAwesome = iAO(NULL, 0);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(hAwesome);
   IndicatorRelease(hOscFast);
   IndicatorRelease(hOscSlow);
   IndicatorRelease(hMA);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
    MqlTradeRequest request = {0};
    MqlTradeResult result;
    MqlDateTime dt;
    bool bord = false, sord = false;
    datetime t[];
    double h[], l[], OscSlow[], OscFast[], Awesome[],
        account_balance, lot_size,
        StopLevel = _Point * SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL),
        Spread = NormalizeDouble( SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits);
    
    
    account_balance = AccountInfoDouble(ACCOUNT_EQUITY);
    lot_size = MathFloor(account_balance/LotSafety) / 100;
    request.symbol = Symbol();
    request.volume = lot_size;
    request.tp = 0;
    request.deviation = 5;
    request.type_filling = ORDER_FILLING_FOK;
    
    TimeCurrent(dt);
    datetime time_current = StructToTime(dt);
    
    // 1. Check if order is placed.
    // 2. if yes, 2.1 check if time to close,
    //            2.2 adjust its StopLoss and TakeProfit
    // 3. if no,  3.1 check indicator for opening a position,
    //            3.2 open a position maybe.
    
    // 0. We will need the indicators either way
    if(CopyBuffer(hOscSlow,0,0,3,OscSlow) < 3 || CopyBuffer(hOscFast,0,0,3,OscFast) < 1 || CopyBuffer(hAwesome,0,0,3,Awesome) < 3) {
        Print("Can't copy indicator buffeh!");
        return;
    }
    ArraySetAsSeries(OscSlow, true);
    ArraySetAsSeries(OscFast, true);
    ArraySetAsSeries(Awesome, true);


    MqlTick last_tick;
    if(SymbolInfoTick(Symbol(),last_tick)) 
        { 
        } 
    else
        {
        Print("SymbolInfoTick() failed, error = ",GetLastError());
        return;
        }

    //1.
    int pos_total = PositionsTotal();
    if(pos_total == 1)
        {
        // processing orders with "our" symbols only
        if(Symbol()==PositionGetSymbol(0))
            {
            //2
            if (time_current - last_checked > CheckSeconds)
                {
                last_checked = time_current;
                request.action=TRADE_ACTION_SLTP;
                if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
                    {
                    double current_price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
                    if (current_price < position_price && current_price < latest_checked_price)
                        {
                        latest_checked_price = current_price;
                        //Short position is loss-free, adjust stoploss
                        request.tp = NormalizeDouble(current_price - TakeProfit * _Point, _Digits);
                        request.sl = NormalizeDouble(current_price + RunningStopLoss * _Point, _Digits);
                        request.magic = EXPERT_MAGIC;
                        OrderSend(request, result);
                        }
                    
                    }
                if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
                    {
                    double current_price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
                    if (current_price > position_price && current_price > latest_checked_price)
                        {
                        latest_checked_price = current_price;
                        //Short position is loss-free, adjust stoploss
                        request.tp = NormalizeDouble(current_price + TakeProfit * _Point, _Digits);
                        request.sl = NormalizeDouble(current_price - RunningStopLoss * _Point, _Digits);
                        request.magic = EXPERT_MAGIC;
                        OrderSend(request, result);
                        }
                    
                    }
                }
            
            return;
            
            }       
        }
    else if(pos_total == 0)
        {
        //3.
        
        if(CopyTime(Symbol(),0,0,2,t)<2 || CopyHigh(Symbol(),0,0,2,h)<2 || CopyLow(Symbol(),0,0,2,l)<2)
            {
               Print("Can't copy timeserieh!");
               return;
            }        
        double diff = OscSlow[1] - OscFast[1];
        
        //Check short indication
        if (OscSlow[1] > SellCutoff && OscSlow[2] > SellCutoff && diff > OscDiff)
            {
            request.action = TRADE_ACTION_DEAL;
            request.price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
            request.type = ORDER_TYPE_SELL;
            request.tp = NormalizeDouble(last_tick.bid - TakeProfit * _Point, _Digits);
            request.sl = NormalizeDouble(last_tick.ask + StopLoss * _Point, _Digits);
            request.magic = EXPERT_MAGIC;
            position_price = request.price;
            latest_checked_price = request.price;
            }
        //Check long indication
        else if (OscSlow[1] < BuyCutoff && OscSlow[2] < BuyCutoff && diff < -(OscDiff))
            {
            request.action = TRADE_ACTION_DEAL;
            request.price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
            request.type = ORDER_TYPE_BUY;
            request.tp = NormalizeDouble(last_tick.ask + TakeProfit * _Point, _Digits);
            request.sl = NormalizeDouble(last_tick.bid - StopLoss * _Point, _Digits);
            request.magic = EXPERT_MAGIC;
            position_price = request.price;
            latest_checked_price = request.price;
            }
        else
            {
            return;
            }
            
        //Perform order
        
        OrderSend(request,result);
        
        }
    else
        {
        Print("Error: too many positions!");
        return;
        }    

/*
    
// in this loop we're checking all opened positions
   for(i=0;i<PositionsTotal();i++)
     {
      // processing orders with "our" symbols only
      if(Symbol()==PositionGetSymbol(i))
        {
         // we will change the values of StopLoss and TakeProfit
         request.action=TRADE_ACTION_SLTP;
         // long positions processing
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            // let's determine StopLoss
            if(ma[1]>PositionGetDouble(POSITION_PRICE_OPEN)) StopLoss=ma[1]; else StopLoss=lev_l;
            // if StopLoss is not defined or lower than needed            
            if((PositionGetDouble(POSITION_SL)==0 || NormalizeDouble(StopLoss-PositionGetDouble(POSITION_SL),_Digits)>0
               // if TakeProfit is not defined or higer than needed
               || PositionGetDouble(POSITION_TP)==0 || NormalizeDouble(PositionGetDouble(POSITION_TP)-atr_h[0],_Digits)>0)
               // is new StopLoss close to the current price?
               && NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID)-StopLoss-StopLevel,_Digits)>0
               // is new TakeProfit close to the current price?
               && NormalizeDouble(atr_h[0]-SymbolInfoDouble(Symbol(),SYMBOL_BID)-StopLevel,_Digits)>0)
              {
               // putting new value of StopLoss to the structure
               request.sl=NormalizeDouble(StopLoss,_Digits);
               // putting new value of TakeProfit to the structure
               request.tp=NormalizeDouble(atr_h[0],_Digits);
               // sending request to trade server
               OrderSend(request,result);
              }
           }
         // short positions processing
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            // let's determine the value of StopLoss
            if(ma[1]+Spread<PositionGetDouble(POSITION_PRICE_OPEN)) StopLoss=ma[1]+Spread; else StopLoss=lev_h;
            // if StopLoss is not defined or higher than needed
            if((PositionGetDouble(POSITION_SL)==0 || NormalizeDouble(PositionGetDouble(POSITION_SL)-StopLoss,_Digits)>0
               // if TakeProfit is not defined or lower than needed
               || PositionGetDouble(POSITION_TP)==0 || NormalizeDouble(atr_l[0]-PositionGetDouble(POSITION_TP),_Digits)>0)
               // is new StopLoss close to the current price?
               && NormalizeDouble(StopLoss-SymbolInfoDouble(Symbol(),SYMBOL_ASK)-StopLevel,_Digits)>0
               // is new TakeProfit close to the current price?
               && NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_ASK)-atr_l[0]-StopLevel,_Digits)>0)
              {
               // putting new value of StopLoss to the structure
               request.sl=NormalizeDouble(StopLoss,_Digits);
               // putting new value of TakeProfit to the structure
               request.tp=NormalizeDouble(atr_l[0],_Digits);
               // sending request to trade server
               OrderSend(request,result);
              }
           }
         // if there is an opened position, return from here...
         return;
        }
     }
*/
   return;
   
   }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
