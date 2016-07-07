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
//--- input parameters
input double   LotSafety=20;
input int      StartHour=0;
input int      EndHour=24;
input int      MAper=240;
input int      BuyCutoff=75;
input int      SellCutoff=35;
input int      OscDiff=30;


int hMA, hCI;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   hMA = iMA(NULL, 0, MAper, 0, MODE_SMA, PRICE_CLOSE);
   hOscSlow = iStochastic(NULL, 0, 21, 4, 10, MODE_SMA, PRICE_CLOSE);
   hOscFast = iStochastic(NULL, 0, 5, 2, 2, MODE_SMA, PRICE_CLOSE);
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
    MqlTradeRequest request;
    MqlTradeResult result;
    MqlDateTime dt;
    bool bord = false, sord = false;
    int i;
    ulong ticket;
    datetime t[];
    double h[], l[], OscSlow[], OscFast[], Awesome[],
        lev_h, lev_l, StopLoss, account_balance, lot_size,
        StopLevel = _Point * SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL),
        Spread = NormalizeDouble( SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits);
    
    
    account_balance = AccountInfoDouble(ACCOUNT_EQUITY);
    lot_size = MathFloor(account_balance/LotSafety) / 100;
    request.symbol = Symbol();
    request.volume = lot_size;
    request.tp = 0;
    request.deviation = 0;
    request.type_filling = ORDER_FILLING_FOK;
    
    TimeCurrent(dt);
    
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

    //1.
    int pos_total = PositionsTotal();
    if(pos_total == 1)
        {
        // processing orders with "our" symbols only
        if(Symbol()==PositionGetSymbol(0))
            {
            //2.
            MqlTick last_tick;
            if(SymbolInfoTick(Symbol(),last_tick)) 
                { 
                Print(last_tick.time,": Bid = ",last_tick.bid, 
                    " Ask = ",last_tick.ask,"  Volume = ",last_tick.volume); 
                } 
            else Print("SymbolInfoTick() failed, error = ",GetLastError()); 
            
            }       
        }
    else if(pos_total == 0)
        {
        //3.
        double latest_slow = OscSlow[1];
        double latest_fast = OscFast[1];
        if
        }
    else
        {
        Print("Error: too many positions!");
        return;
        }    
    
    ArraySetAsSeries(ma, true);
    atr_l[0] += Spread;
    
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
    
    
// in this loop we're checking all pending orders
   for(i=0;i<OrdersTotal();i++)
     {
      // choosing each order and getting its ticket
      ticket=OrderGetTicket(i);
      // processing orders with "our" symbols only
      if(OrderGetString(ORDER_SYMBOL)==Symbol())
        {
         // processing Buy Stop orders
         if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_STOP)
           {
            // check if there is trading time and price movement is possible
            if(dt.hour>=StartHour && dt.hour<EndHour && lev_h<atr_h[0])
              {
               // if the opening price is lower than needed
               if((NormalizeDouble(lev_h-OrderGetDouble(ORDER_PRICE_OPEN),_Digits)>0
                  // if StopLoss is not defined or higher than needed
                  || OrderGetDouble(ORDER_SL)==0 || NormalizeDouble(OrderGetDouble(ORDER_SL)-lev_l,_Digits)!=0)
                  // is opening price close to the current price?
                  && NormalizeDouble(lev_h-SymbolInfoDouble(Symbol(),SYMBOL_ASK)-StopLevel,_Digits)>0)
                 {
                  // pending order parameters will be changed
                  request.action=TRADE_ACTION_MODIFY;
                  // putting the ticket number to the structure
                  request.order=ticket;
                  // putting the new value of opening price to the structure
                  request.price=NormalizeDouble(lev_h,_Digits);
                  // putting new value of StopLoss to the structure
                  request.sl=NormalizeDouble(lev_l,_Digits);
                  // sending request to trade server
                  OrderSend(request,result);
                  // exiting from the OnTick() function
                  return;
                 }
              }
            // if there is no trading time or the average trade range has been passed
            else
              {
               // we will delete this pending order
               request.action=TRADE_ACTION_REMOVE;
               // putting the ticket number to the structure
               request.order=ticket;
               // sending request to trade server
               OrderSend(request,result);
               // exiting from the OnTick() function
               return;
              }
            // setting the flag, that indicates the presence of Buy Stop order
            bord=true;
           }
         // processing Sell Stop orders
         if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP)
           {
            // check if there is trading time and price movement is possible
            if(dt.hour>=StartHour && dt.hour<EndHour && lev_l>atr_l[0])
              {
               // if the opening price is higher than needed
               if((NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN)-lev_l,_Digits)>0
                  // if StopLoss is not defined or lower than need
                  || OrderGetDouble(ORDER_SL)==0 || NormalizeDouble(lev_h-OrderGetDouble(ORDER_SL),_Digits)>0)
                  // is opening price close to the current price?
                  && NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID)-lev_l-StopLevel,_Digits)>0)
                 {
                  // pending order parameters will be changed
                  request.action=TRADE_ACTION_MODIFY;
                  // putting ticket of modified order to the structure
                  request.order=ticket;
                  // putting new value of the opening price to the structure
                  request.price=NormalizeDouble(lev_l,_Digits);
                  // putting new value of StopLoss to the structure
                  request.sl=NormalizeDouble(lev_h,_Digits);
                  // sending request to trade server
                  OrderSend(request,result);
                  // exiting from the OnTick() function
                  return;
                 }
              }
            // if there is no trading time or the average trade range has been passed�
            else
              {
               // we will delete this pending order
               request.action=TRADE_ACTION_REMOVE;
               // putting the ticket number to the structure
               request.order=ticket;
               // sending request to trade server
               OrderSend(request,result);
               // exiting from the OnTick() function
               return;
              }
            // setting the flag, that indicates the presence of Sell Stop order
            sord=true;
           }
        }
     }
     
    request.action=TRADE_ACTION_PENDING;     


      if(dt.hour>=StartHour && dt.hour<EndHour)
        {
         if(bord==false && lev_h<atr_h[0])
           {
            request.price=NormalizeDouble(lev_h,_Digits);
            request.sl=NormalizeDouble(lev_l,_Digits);
            request.type=ORDER_TYPE_BUY_STOP;
            OrderSend(request,result);
           }
         if(sord==false && lev_l>atr_l[0])
           {
            request.price=NormalizeDouble(lev_l,_Digits);
            request.sl=NormalizeDouble(lev_h,_Digits);
            request.type=ORDER_TYPE_SELL_STOP;
            OrderSend(request,result);
           }
        }
   
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
