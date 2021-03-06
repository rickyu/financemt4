//+------------------------------------------------------------------+
//|                                                        Order.mqh |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
 
 struct COrder  
 {
 public:
      int ticket;
      int type;
      double lots;
      double open_price;
      double close_price;
      datetime close_time;
 public:
      bool IsClosed() { return close_time != 0;}
      bool IsLost();
 };

  
  
  class COrderManager
  {
  public:
      // @param long_or_short: 1:多头，2，空头(sell), 0： 全部
      // @return : 返回的订单个数, <0 表示出错.
      int SelectOrders(string symbol, int long_or_short,   COrder& orders[]);
      int SelectOrdersByBreakthrough(string symbol, int breakthrough_id, COrder &orders[]);
      int SelectOrders(const string symbol, COrder& orders[]);
      // 参考http://book.mql4.com/appendix/limits 自动做价格微调
      int OpenOrderSmart(const string symbol, int cmd, double volume, double price, int slippage, double stoploss);
      int OpenOrder(const string symbol, int cmd, double volume, double price, int slippage, double stoploss);
      int CloseOrder(int ticket,double price);
      
  
      int Count();
      int Sum();
  private:
      void FillOrder(COrder& order);
  };
  
bool COrder::IsLost() 
{
    if (IsClosed()) {
         if (type == OP_BUY && open_price > close_price) {
             return true;
         }
         if (type == OP_SELL && open_price < close_price) {
             return true;
         }
     }
     return false; 
}
  int COrderManager::SelectOrders(string symbol, int long_or_short, COrder &orders[])
  {
      int count = 0;
      if (ArrayResize(orders, OrdersTotal(), OrdersHistoryTotal() + OrdersTotal()) < 0) {
          return -__LINE__;
      }
      for (int i=0; i<OrdersTotal(); ++i) {
          OrderSelect(i, SELECT_BY_POS);
          if (OrderSymbol() == symbol) {
            if ( 0 == long_or_short || (1 == long_or_short && (OrderType() == OP_BUY || OrderType() == OP_BUYLIMIT)) 
                || (2 == long_or_short && (OrderType() == OP_SELL || OrderType() == OP_BUYLIMIT))) {
                FillOrder(orders[count++]);

            }          
          }
      }
      return count;
  }
  
  int COrderManager::SelectOrders(const string symbol, COrder &orders[])
  {
      int count = 0;
      if (ArrayResize(orders, OrdersTotal(), OrdersHistoryTotal() + OrdersTotal()) < 0) {
          return -__LINE__;
      }
      for (int i=0; i<OrdersTotal(); ++i) {
          OrderSelect(i, SELECT_BY_POS);
          if (OrderSymbol() == symbol) {
              FillOrder(orders[count++]);       
          }
      }
      return count;
  }
  
  
  int COrderManager::SelectOrdersByBreakthrough(string symbol,  int breakthrough_id, COrder &orders[])
  {
      int count = 0;
      if (ArrayResize(orders, OrdersTotal()+ OrdersHistoryTotal(), OrdersHistoryTotal() + OrdersTotal()) < 0) {
          return -__LINE__;
      }
      for (int i=0; i<OrdersTotal(); ++i) {
          OrderSelect(i, SELECT_BY_POS);
          if (OrderSymbol() == symbol) {
            if ( OrderMagicNumber() == breakthrough_id) {
                FillOrder(orders[count++]);

            }          
          }
      }
      for (int i=0; i<OrdersHistoryTotal(); ++i) {
          OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
          if (OrderSymbol() == symbol) {
             if (OrderMagicNumber() == breakthrough_id) {
                FillOrder(orders[count++]);               
             }
          }
      }
      return count;
      
  }
  void COrderManager::FillOrder(COrder& order)
  {
    order.ticket = OrderTicket();
    order.lots = OrderLots();
    order.open_price = OrderOpenPrice();
    order.type = OrderType();
  }
  
  int COrderManager::OpenOrder(const string symbol, int cmd, double volume, double price, int slippage, double stoploss)
  {
      return OrderSend(symbol, cmd, volume, price, slippage, stoploss, 0.0);
  }
  
  int COrderManager::OpenOrderSmart(const string symbol, int cmd, double volume, double price, int slippage, double stoploss)
  {
      switch(cmd) {
          case OP_BUY:
              {
                  double market_price = MarketInfo(symbol, MODE_ASK);
                  double sl = MarketInfo(symbol, MODE_BID) - MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT);
                  stoploss = stoploss < sl ? stoploss : sl;
                  stoploss = NormalizeDouble(stoploss, MarketInfo(symbol, MODE_DIGITS));        
                  
              }
              break;
           case OP_SELL:
              {
                  double market_price = MarketInfo(symbol, MODE_BID);
                  double sl = market_price + MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT);
                  stoploss = stoploss > sl ? stoploss : sl;
                  stoploss = NormalizeDouble(stoploss, MarketInfo(symbol, MODE_DIGITS));   
              }
              break;
      }
      return OrderSend(symbol, cmd, volume, price, slippage, stoploss, 0);
  }