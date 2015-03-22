//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
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
#include <Object.mqh>
#include "Breakthrough.mqh"
#include "Order.mqh"
#include "Symbol.mqh"
double iTR(string symbol, int timeframe, int shift)
{
  double TR = 0.0;
  double H = iHigh(symbol, timeframe, shift);
  double L = iLow(symbol, timeframe, shift);
  double PDC = iClose(symbol, timeframe, shift+1);
  TR = MathMax(H-L, MathMax(H-PDC, PDC-L));
  return TR;
}
double iN(string symbol, int timeframe, int period, int shift)
{
  double TR[];
  ArrayResize(TR, period);
  double sum = 0.0;
  
  for (int i=0; i<period; ++i) {
    sum  += iTR(symbol, timeframe, shift+i);
    
  }
  sum /= period;
  return sum;

}
class CStrategy : public CObject
{
public:

};
struct Tick
{
    datetime timestamp;
    double ask;
    double bid;
    //string symbol;
};

struct PeriodInfo
{
    datetime begin;
    datetime end;
    
};
class CPositionManager
{
public:
   void Update(bool force = false);
};

class System1Config
{
public:
    string symbol;
    int timeframe;
    int slippage;
    double fund; // 资金数量
    double stop_loss_times_n; // 止损差值,书上是2
    double order_price_range_times_n; // 下单价和理想价格之间的差距必须小于 order_price_range_times_n * N
    bool use_limit_order;// 使用限价订单
    int magic; // 用来标识订单的magicNumber
    int refresh_interval_of_U; // 头寸规模刷新周期，
    System1Config() {
        symbol = Symbol();
        timeframe = PERIOD_CURRENT;
        slippage = 3;
        fund = 10000;
        stop_loss_times_n = 2;
        order_price_range_times_n = 0.5;
        use_limit_order = false;
        magic = 0x01;
        refresh_interval_of_U = 7;
    }
    System1Config(const System1Config& cfg)
     {
        Copy(cfg);    
    }
    void Copy(const System1Config& cfg) 
    {
        symbol = cfg.symbol;
        timeframe = cfg.timeframe;
        slippage = cfg.slippage;
        fund = cfg.fund;
        stop_loss_times_n = cfg.stop_loss_times_n;
        order_price_range_times_n = cfg.order_price_range_times_n;
        use_limit_order = cfg.use_limit_order;
        magic = cfg.magic; 
        refresh_interval_of_U = cfg.refresh_interval_of_U;     
    }
    string ToString() {
        string s = "symbol="+symbol;
        s += ",timeframe=" + timeframe;
        s += ",slippage=" + slippage;
        return s;
    }
};
enum EnumEnterSignalType
{
    ENTER_SIGNAL_TYPE_IGNORE = 0,
    ENTER_SIGNAL_TYPE_BUY,
    ENTER_SIGNAL_TYPE_SELL
};
struct EnterSignal
{
    EnumEnterSignalType  type; // 
    double price;
};
class CSystem1Strategy
{
public:
    CSystem1Strategy() {
        period_time_ = 0;
        last_refresh_time_of_U_  = 0;
    }
    void Init(const System1Config& config) {
        config_.Copy(config);
    }
    void ProcessTick(const Tick& tick);
    void Deinit();
private:
   

    bool IsCurrentPeriod(datetime t); 
 
    void EnterMarket();
    void ExitMarket();
    void RefreshPeriodData();
    // 算出入市信号
    int GetEnterSignal(EnterSignal& signal);
    // 根据入市信号下订单
    int PlaceOrder(EnumOrderDirection direction, double price);
    // 更新上次突破，看是亏损还是盈利
    void RefreshLastBreakThrough();
    void RollBreakThrough(EnumBreakThourghDirection direction, double price, int bars);
   
    // 进行头寸规模限制
    bool IsPositionFull(EnumOrderDirection direction);
    // 出错处理，比如订单方向不一致等情况
    int CheckError();
     // 尝试更新头寸单位, 如果头寸单位发生变化，则看是否需要更新订单
      void RefreshPositionUnit();
    // 处理头寸规模发生变化的情况
    void OnUChanged(double U, double oldU);
private:
    Tick tick_;
    
    System1Config config_;
    
    CPositionManager* position_manager_;
    COrderManager order_manager_;
    CSymbolModel symbol_model_;
 
    
    // 每个时间段(bar)内的数据
    datetime period_time_;
    double max_price_of_10_;
    double min_price_of_10_;
    double max_price_of_20_;
    double min_price_of_20_;
    double max_price_of_55_;
    double min_price_of_55_;
    double N_;
    bool already_exit_buy_;
    bool already_exit_sell_;
    
    datetime last_refresh_time_of_U_;
    double U_;
    
    BreakThroughInfo last_break_through_;
    BreakThroughInfo break_through_;
    
    
    
};

void CSystem1Strategy::ProcessTick(const Tick& tick)
{
  // 1. 看是否到时间要更行N，更新N,同时计算所有仓位，看是否需要变化(部分卖出)
  // 2. 计算现有订单是否需要盈利卖出的
  // 3. 看今天是否有突破（入市信号)，如果有不能忽略的入市信号， 则进行如下操作
  //     3.1 如果今天没有交易，根据突破价尝试买入
  //     3.2 如果今天有交易, 尝试按照0.5N的方式加仓
  tick_ = tick;
  RefreshPeriodData();
  RefreshPositionUnit();
  // 获利退出
  ExitMarket();
  // 入市
  EnterMarket();
}

 int CSystem1Strategy::PlaceOrder(EnumOrderDirection direction, double price)
 {
   
    int op = ORDER_BUY == direction ? OP_BUY : OP_SELL;    
//    if (config_.use_limit_order) {
//        op = ORDER_BUY == direction ? OP_BUYLIMIT : OP_SELLLIMIT;
//    } else {       
//        op = ORDER_BUY == direction ? OP_BUY : OP_SELL;
//        
//    }
   
    double order_price ;
    double stoploss;
    switch (op) {
        case OP_BUY:
            order_price = tick_.ask;
            if (order_price - price > config_.order_price_range_times_n * N_ ) {
                   // 当前市场价格和突破价格差距已经太大，超过范围则不下单
                Print("当前市场价格超过突破价格太多");
                return -1;
            }
            stoploss = price - config_.stop_loss_times_n * N_;
            break;
        case OP_SELL:
            order_price = tick_.bid;
            if (price - order_price  > config_.order_price_range_times_n * N_ ) {
                   // 当前市场价格和突破价格差距已经太大，超过范围则不下单
                Print("当前市场价格超过突破价格太多");
                return -1;
            }
            stoploss = order_price + config_.stop_loss_times_n * N_;
            break;            

        
    }
    int ticket = order_manager_.OpenOrder(config_.symbol, op, U_, order_price, config_.slippage, stoploss, config_.magic);
    return ticket;

 }

bool CSystem1Strategy::IsPositionFull(EnumOrderDirection direction)
{
    //进行仓位限制
    COrder orders[];
       // 根据加仓条件进行加仓，最多到4U，中间的突破忽略掉

    // 加仓条件：当前价格超过突破价格(最后订单价格)的0.5N, 1N, 1.5N, 如果已经开仓，则持续加仓到最多4U
   int total_unit = 0;
   int strong_related_unit = 0;
   int weak_related_unit = 0;
   int symbol_count = 0;
    int count = order_manager_.SelectOrders(direction, config_.magic, orders);
    for (int i=0; i<count; ++i) {
        if (orders[i].symbol == config_.symbol) {
           ++symbol_count;
        }
        ++total_unit;
        EnumSymbolRelation relation = symbol_model_.GetRelation(config_.symbol, OrderSymbol());
        if (SYMBOL_RELATION_WEAK == relation) {
            ++weak_related_unit;
        } else if (SYMBOL_RELATION_STRONG == relation) {
            ++strong_related_unit;
            ++weak_related_unit;
        }    
    }

         if (total_unit >= 12 || strong_related_unit >= 6 || weak_related_unit>=10 || symbol_count >= 4) {
            //不能加
            return true;
         }


     return false;

}
 // 入市策略1
  void CSystem1Strategy::EnterMarket()
  {
      COrder orders[];
      int orders_count = order_manager_.SelectOrders(config_.symbol,orders);
      if (orders_count < 0) {
          Print("error:SelectOrder return ", orders_count);
          return;
      }
      
      if (orders_count == 0) {
          // 空仓，准备入场
           //尝试开仓:条件，发生了突破，且突破不能忽略
           // 更新突破信息
           EnterSignal signal;
           int ret = GetEnterSignal(signal);
           if (signal.type == ENTER_SIGNAL_TYPE_IGNORE) {
               return;
           
           }
           
           EnumOrderDirection direction = signal.type == ENTER_SIGNAL_TYPE_BUY ? ORDER_BUY : ORDER_SELL;
           if (!IsPositionFull(direction)) {
               // 这里都是写的期望价格
               Print("Place Order, direction=", direction, ", price=", signal.price);
               PlaceOrder(direction, signal.price);
           }
          
           
      } else {
         bool is_buy = orders[0].IsBuy();
           
          if (IsPositionFull(is_buy ? ORDER_BUY : ORDER_SELL)) {
              return;
          }
         
         double total_lots = 0;
         bool conflict = false;
        
         bool is_sell = orders[0].IsSell();
         bool have_pending = false;
         double max_price = orders[0].open_price;         
         double min_price = orders[0].close_price;
         for (int i=0; i<ArraySize(orders); ++i) {
             total_lots += orders[i].lots;
             if (!orders[0].IsDirectionSame(orders[i])) {
                 // 不算和第一单方向不一样的订单
                 conflict = true;
                 continue;
             }
             if (orders[i].IsPending()) {
                 have_pending = true;
             }
             if (orders[i].open_price > max_price) {
                 max_price = orders[i].open_price;
             }
             if (orders[i].open_price < min_price) {
                 min_price = orders[i].open_price;
             }
            
         }
         if (conflict) {
             Print("同时有卖单和买单");
             // TODO : 怎么处理?
             
         }
         int ticket = -1;
         bool have_op = false;
          if (is_buy
              && tick_.ask >= max_price + 0.5 * N_ 
              && tick_.ask < max_price + 0.5 * N_ + config_.order_price_range_times_n *N_) {
              // 
              // 加仓买
              //ticket = PlaceOrder(ORDER_BUY, tick_.ask);
              ticket = PlaceOrder(ORDER_BUY, max_price + 0.5 * N_);
              have_op = true;
          } 
          if (is_sell 
              && tick_.bid <= min_price - 0.5 * N_ 
              && tick_.bid >= min_price - 0.5 * N_ - config_.order_price_range_times_n * N_) {
              // 加仓卖
              //ticket = PlaceOrder(ORDER_SELL, tick_.bid);
              ticket = PlaceOrder(ORDER_SELL, min_price - 0.5 * N_);
              have_op = true;
          }
          if (!have_op) {
              return;
          }
         
         if (ticket > 0) {
           
            // 设置止损价格，需要调整以前订单的止损价格: 将之前的头寸止损价格提高0.5N
            for (int i=0; i<orders_count;++i) {            
                double new_stoploss = is_buy?orders[i].open_price+0.5*N_:orders[i].open_price-0.5*N_;
                new_stoploss = NormalizeDouble(new_stoploss, MarketInfo(config_.symbol, MODE_DIGITS));
                if (OrderModify(orders[i].ticket, orders[i].open_price, new_stoploss, 0, 0)) {
                    Print("update stoploss succeed:ticket=", orders[i].ticket, ", stoploss=", new_stoploss, ",N=",N_);
                } else {
                    Print("update stoploss fail:ticket=", orders[i].ticket, ", stoploss=", new_stoploss, ",N=",N_, ",error=", GetLastError());
                }
               
            }  
         }
         else   {
             Print("Open order error:", GetLastError());
            
         }
          
      }      
  }
void CSystem1Strategy::ExitMarket(void)
{
     if (!already_exit_buy_ && tick_.bid < min_price_of_10_) {
         already_exit_buy_ = true;         
         Print("Exit: 跌破10日低点,bid= ", tick_.bid, ",price_min_10d=", min_price_of_10_);
         order_manager_.CloseOrders(config_.symbol, true, tick_.bid, config_.slippage);
     }
     
     if (!already_exit_sell_ && tick_.ask > max_price_of_10_) {
         already_exit_sell_  = true;
         Print("Exit: 突破10日高点,ask= ", tick_.ask, ",price_max_10d=", max_price_of_10_);
          order_manager_.CloseOrders(config_.symbol, false, tick_.ask, config_.slippage);
 
     }
}
void CSystem1Strategy::RefreshLastBreakThrough()
{
    if (!last_break_through_.IsValid()) {
        return;
    }
    if (last_break_through_.trade_status != TRADE_STATUS_HOLD) {
        return;
    }


   if (BREAK_THROUGH_UP == last_break_through_.direction) {
        // 假设是个买单
        if (tick_.bid < last_break_through_.price - config_.stop_loss_times_n * N_) {
            last_break_through_.trade_status = TRADE_STATUS_LOSS;// 亏损
        } else if (tick_.bid < min_price_of_10_) {
            if (tick_.bid > last_break_through_.price) {
                last_break_through_.trade_status = TRADE_STATUS_PROFIT;// 盈利
            } else {
                last_break_through_.trade_status = TRADE_STATUS_LOSS;// 亏损
            }
        }
   } else {
        // 假设是个卖单
        if (tick_.ask > last_break_through_.price + config_.stop_loss_times_n * N_) {
            last_break_through_.trade_status = TRADE_STATUS_LOSS;// 亏损
        } else if (tick_.ask > max_price_of_10_) {
            if (tick_.ask < last_break_through_.price) {
                last_break_through_.trade_status = TRADE_STATUS_PROFIT;// 盈利
            } else {
                last_break_through_.trade_status = TRADE_STATUS_LOSS;// 盈利
            }
        }
   }
        
    
}

void CSystem1Strategy::RollBreakThrough(EnumBreakThourghDirection direction, double price, int bars)
{
    if (break_through_.IsValid()
         && IsCurrentPeriod(break_through_.t) 
         && break_through_.direction == direction) {
        // 同一个时间周期，相同方向的突破忽略
        return;

    }
    if (break_through_.IsValid()) {
        last_break_through_ = break_through_;
        
    }
    Print("突破了", bars,",ts=", tick_.timestamp, ", dir=", BREAK_THROUGH_DOWN == direction ? "down" : "up", ", price=", price );
    break_through_.Init(tick_.timestamp, direction, price);
}
int CSystem1Strategy::GetEnterSignal(EnterSignal &signal)
{
    
    // 更新上次突破，看是盈利还是亏损
    RefreshLastBreakThrough();

    // 重新计算突破
    // 55日突破不用看上次突破
    if (tick_.ask > max_price_of_55_) {
    // 55突破
        signal.price = max_price_of_55_;
        signal.type = ENTER_SIGNAL_TYPE_BUY;
        
        RollBreakThrough(BREAK_THROUGH_UP, max_price_of_20_, 55);
        return 0;
    }
    if (tick_.bid < min_price_of_55_) {
        signal.price = min_price_of_55_;
        signal.type = ENTER_SIGNAL_TYPE_SELL;
        RollBreakThrough(BREAK_THROUGH_DOWN, min_price_of_20_, 55);
        return 0;
    }
    if (tick_.ask > max_price_of_20_) {
        RollBreakThrough(BREAK_THROUGH_UP, max_price_of_20_, 20);
        if (last_break_through_.IsLoss()) {
            signal.price = max_price_of_20_;
            signal.type = ENTER_SIGNAL_TYPE_BUY;           
            return 0;
        }
    }
    if (tick_.bid < min_price_of_20_) {
        RollBreakThrough(BREAK_THROUGH_DOWN, max_price_of_20_, 20);
        if (last_break_through_.IsLoss()) {
            signal.price = min_price_of_20_;
            signal.type = ENTER_SIGNAL_TYPE_SELL;
            return 0;
        }
    }
    signal.type = ENTER_SIGNAL_TYPE_IGNORE;
    signal.price = 0;
    return 0;

}

bool CSystem1Strategy::IsCurrentPeriod(datetime t) 
{
    int bar =  iBarShift(config_.symbol, config_.timeframe, t, false);
    //Print("t=", t, ",shift=", bar);
    if (bar == 0) { 
        return true;
    }  else {
        return false;
    }
}
void CSystem1Strategy::RefreshPeriodData()
 {
    
   if (!IsCurrentPeriod(period_time_)) {
       // 更新period中的数据
       period_time_ = tick_.timestamp;       
       max_price_of_10_ = iHigh(config_.symbol, config_.timeframe, iHighest(config_.symbol, config_.timeframe, MODE_HIGH, 10, 1));
       min_price_of_10_ = iLow(config_.symbol, config_.timeframe, iLowest(config_.symbol, config_.timeframe, MODE_LOW, 10, 1));
       max_price_of_20_ = iHigh(config_.symbol, config_.timeframe, iHighest(config_.symbol, config_.timeframe, MODE_HIGH, 20, 1));
       min_price_of_20_ = iLow(config_.symbol, config_.timeframe, iLowest(config_.symbol, config_.timeframe, MODE_LOW, 20, 1));
       max_price_of_55_ = iHigh(config_.symbol, config_.timeframe, iHighest(config_.symbol, config_.timeframe, MODE_HIGH, 55, 1));
       min_price_of_55_ = iLow(config_.symbol, config_.timeframe, iLowest(config_.symbol, config_.timeframe, MODE_LOW, 55, 1));  
       N_ = iN(config_.symbol, config_.timeframe, 20, 1);
       double N = iATR(config_.symbol, config_.timeframe, 20, 1);
       already_exit_buy_ = false;
       already_exit_sell_ = false; 
       //Print("time=", tick_.timestamp, ",N=", N_, ",atr=", N); 
   }  
 }
 
 
/** 计算每点代表的美元数 */
double GetDollarsPerPoint(string symbol)
{
   double currency = MarketInfo(symbol, MODE_LOTSIZE) * MarketInfo(symbol, MODE_POINT);
   string account_currency = AccountCurrency();
   string quote_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   if (account_currency == quote_currency) {
       return currency;
   } else {
      // 查找汇率 quote->account
      if (quote_currency == "JPY") {
          return currency / MarketInfo("USDJPYpro", MODE_ASK);
          
      }
      if (quote_currency == "AUD") {
          return currency * MarketInfo("AUDUSDpro", MODE_BID);
      }
      if (quote_currency == "CAD") {
          return currency / MarketInfo("USDCADpro", MODE_ASK);
      }
   }
   return 0;

}

 

// 计算头寸规模单位，算法：头寸规模单位=账户的1%/市场的绝对波动幅度=账户的1%/(N * 每一点代表的美元数)
// 返回值：合约数，比如外汇的最小合约数是0.01，
void  CSystem1Strategy::RefreshPositionUnit() 
{
   int shift = iBarShift(config_.symbol, config_.timeframe, last_refresh_time_of_U_);
   if (shift <  config_.refresh_interval_of_U ) {
       return;
   }
   double old_U = U_;
   last_refresh_time_of_U_ = tick_.timestamp;
   double N_ = iATR(config_.symbol, config_.timeframe, 20, 1);
   double N = N_ /MarketInfo(config_.symbol, MODE_POINT);  
   double fund_per_point =  GetDollarsPerPoint(config_.symbol);
   U_ = config_.fund * 0.01 / (N * fund_per_point);
   double minlot = MarketInfo(config_.symbol, MODE_MINLOT);
   double lotstep = MarketInfo(config_.symbol, MODE_LOTSTEP);
   if (U_ < minlot) {
      // 1个最小的lot都不能买，这个symbol不能交易
       U_ = 0;
   } else {
       int times =  (U_ - minlot ) / lotstep;
       U_ = minlot + times * lotstep;
   }
   OnUChanged(U_, old_U);   
}


void  CSystem1Strategy::OnUChanged(double U, double oldU)
{
    Print("U changed from ", oldU, " to " , U);
}
