//+------------------------------------------------------------------+
//|                                                  SSL_Hybrid.mq5 |
//|                                Copyright 2023, Your Company |
//|                                   https://www.yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Company"
#property link      "https://www.yourwebsite.com"
#property version   "3.10"
#property description "SSL Hybrid with Hull Moving Average - TradingView style"
#property indicator_chart_window
#property indicator_buffers 13
#property indicator_plots   6

// SSL line
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGray,clrDeepSkyBlue,clrMagenta
#property indicator_width1  3
#property indicator_label1  "SSL Hybrid"

// Baseline
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrGray,clrDeepSkyBlue,clrMagenta
#property indicator_width2  2
#property indicator_label2  "Baseline"

// ATR Upper Band
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrWhite
#property indicator_width3  1
#property indicator_style3  STYLE_DOT
#property indicator_label3  "+ATR"

// ATR Lower Band
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrWhite
#property indicator_width4  1
#property indicator_style4  STYLE_DOT
#property indicator_label4  "-ATR"

// Keltner Upper Channel
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGray
#property indicator_width5  1
#property indicator_style5  STYLE_DOT
#property indicator_label5  "Keltner Upper"

// Keltner Lower Channel
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrGray
#property indicator_width6  1
#property indicator_style6  STYLE_DOT
#property indicator_label6  "Keltner Lower"

// Input parameters
input int                SSL_Period = 60;          // SSL Period
input ENUM_MA_METHOD     MA_Method = MODE_LWMA;    // MA Method
input double             ATR_Multiplier = 1.5;     // ATR Multiplier
input int                ATR_Period = 14;          // ATR Period
input bool               Show_Baseline = true;     // Show Baseline (default: ON)
input bool               Show_ATR_Bands = false;   // Show ATR Bands (default: OFF)
input bool               Show_Keltner = false;     // Show Keltner Channel (default: OFF)
input double             Keltner_Multiplier = 0.2; // Keltner Channel Multiplier
input bool               Color_Bars = false;       // Color Chart Bars (default: OFF)
input int                Max_Colored_Bars = 300;   // Maximum bars to color (performance)

// Indicator buffers
double SSLBuffer[];         // SSL line values
double SSLColorBuffer[];    // SSL color index
double BaselineBuffer[];    // Baseline values
double BaselineColorBuffer[];// Baseline color index
double ATRUpperBuffer[];    // ATR upper band
double ATRLowerBuffer[];    // ATR lower band
double KeltnerUpperBuffer[];// Keltner upper channel
double KeltnerLowerBuffer[];// Keltner lower channel
double ATRBuffer[];         // ATR values (internal)
double RangeMABuffer[];     // Range MA for Keltner (internal)
double HMAHighBuffer[];     // HMA of high (internal)
double HMALowBuffer[];      // HMA of low (internal)
double DirectionBuffer[];   // Direction buffer (internal)

// Indicator handle
int atrHandle;

// For incremental calculation
int last_calculated = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   // Set indicator buffers
   SetIndexBuffer(0, SSLBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SSLColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BaselineBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BaselineColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, ATRUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, ATRLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, KeltnerUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, KeltnerLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(8, ATRBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, RangeMABuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, HMAHighBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, HMALowBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, DirectionBuffer, INDICATOR_CALCULATIONS);
   
   // Set buffer accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   // Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, 0.0);
   
   // Set visibility based on inputs - DEFAULT: Only show SSL line and Baseline
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, Show_Baseline ? DRAW_COLOR_LINE : DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, Show_ATR_Bands ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, Show_ATR_Bands ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, Show_Keltner ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, Show_Keltner ? DRAW_LINE : DRAW_NONE);
   
   // Set buffer labels
   PlotIndexSetString(0, PLOT_LABEL, "SSL Hybrid");
   PlotIndexSetString(1, PLOT_LABEL, "Baseline");
   PlotIndexSetString(2, PLOT_LABEL, "+ATR");
   PlotIndexSetString(3, PLOT_LABEL, "-ATR");
   PlotIndexSetString(4, PLOT_LABEL, "Keltner Upper");
   PlotIndexSetString(5, PLOT_LABEL, "Keltner Lower");
   
   // Set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "SSL Hybrid(" + IntegerToString(SSL_Period) + ")");
   
   // Set drawing begin
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, SSL_Period);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, SSL_Period);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, SSL_Period);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, SSL_Period);
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, SSL_Period);
   PlotIndexSetInteger(5, PLOT_DRAW_BEGIN, SSL_Period);
   
   // Create ATR handle
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(atrHandle == INVALID_HANDLE) {
      Print("Error creating ATR handle: ", GetLastError());
      return(INIT_FAILED);
   }
   
   // Clear any previous objects if reloading
   if(Color_Bars) {
      ObjectsDeleteAll(0, "SSLBarColor_");
   }
   
   // Reset calculation tracking
   last_calculated = 0;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Release ATR handle
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
      
   // Clean up chart objects
   if(Color_Bars) {
      // Delete all bar coloring objects
      ObjectsDeleteAll(0, "SSLBarColor_");
   }
}

//+------------------------------------------------------------------+
//| Calculate MA based on specified method                           |
//+------------------------------------------------------------------+
double CalculateMA(const double& prices[], int period, int pos, ENUM_MA_METHOD method) {
   // Validation to prevent array out-of-bounds access
   if(pos < 0 || period <= 1 || pos < period - 1)
      return prices[pos];
   
   double result = 0;
   
   // Calculate MA based on selected method
   switch(method) {
      case MODE_SMA: // Simple Moving Average
         {
            double sum = 0;
            int count = 0;
            
            for(int i = 0; i < period && pos - i >= 0; i++) {
               sum += prices[pos - i];
               count++;
            }
            
            result = (count > 0) ? sum / count : prices[pos];
         }
         break;
         
      case MODE_EMA: // Exponential Moving Average
         {
            double alpha = 2.0 / (period + 1.0);
            result = prices[pos];
            
            for(int i = 1; i < period && pos - i >= 0; i++) {
               result = alpha * prices[pos - i] + (1 - alpha) * result;
            }
         }
         break;
         
      case MODE_SMMA: // Smoothed Moving Average
         {
            double sum = 0;
            
            for(int i = 0; i < period && pos - i >= 0; i++) {
               sum += prices[pos - i];
            }
            
            result = sum / period;
         }
         break;
         
      case MODE_LWMA: // Linear Weighted Moving Average
      default:
         {
            double sum = 0, weight = 0;
            
            for(int i = 0; i < period && pos - i >= 0; i++) {
               double w = period - i;
               sum += prices[pos - i] * w;
               weight += w;
            }
            
            result = (weight > 0) ? sum / weight : prices[pos];
         }
         break;
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Calculate HMA (Hull Moving Average) with specified MA method     |
//+------------------------------------------------------------------+
void CalculateHMA(const double& source[], int period, int start, int end, double& output[], ENUM_MA_METHOD method) {
   // Validation
   if(period <= 1 || end < start || start < period)
      return;
   
   int halfPeriod = (int)MathFloor(period / 2.0);
   int sqrtPeriod = (int)MathRound(MathSqrt(period));
   
   // Create temporary arrays for calculations
   double wma1[];
   double wma2[];
   double raw_hma[];
   
   int size = end - start + 1;
   ArrayResize(wma1, size);
   ArrayResize(wma2, size);
   ArrayResize(raw_hma, size);
   
   // Calculate MA with period and half period - optimize to calculate only for needed range
   for(int i = 0; i < size; i++) {
      int pos = start + i;
      wma1[i] = CalculateMA(source, period, pos, method);
      wma2[i] = CalculateMA(source, halfPeriod, pos, method);
      
      // Calculate 2 * WMA(n/2) - WMA(n) in the same loop
      raw_hma[i] = 2 * wma2[i] - wma1[i];
   }
   
   // Calculate final HMA (WMA of raw_hma with sqrt(period))
   for(int i = 0; i < size; i++) {
      int pos = i;  // Position in our temporary array
      
      // We need at least sqrtPeriod values for final WMA
      if(pos >= sqrtPeriod - 1) {
         double sum = 0, weight = 0;
         
         for(int j = 0; j < sqrtPeriod; j++) {
            double w = sqrtPeriod - j;
            sum += raw_hma[pos - j] * w;
            weight += w;
         }
         
         output[start + i] = (weight > 0) ? sum / weight : raw_hma[pos];
      }
      else {
         // Not enough data for full calculation, use partial data
         output[start + i] = raw_hma[pos];
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up old bar color objects to improve performance            |
//+------------------------------------------------------------------+
void CleanupOldBarObjects(const datetime& time[], int visible_bars) {
   datetime oldest_visible = time[MathMax(0, ArraySize(time) - visible_bars)];
   
   // Find and delete objects for bars that are no longer visible
   for(int i = ObjectsTotal(0, 0, OBJ_RECTANGLE) - 1; i >= 0; i--) {
      string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      
      // Only process our bar color objects
      if(StringFind(name, "SSLBarColor_") == 0) {
         // Get time of object
         datetime obj_time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         
         // Remove if older than oldest visible bar
         if(obj_time < oldest_visible) {
            ObjectDelete(0, name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[]) {
   
   // Check for minimum bars
   if(rates_total < SSL_Period)
      return 0;
   
   // Define calculation start point
   int start;
   
   // If first calculation or reset
   if(prev_calculated == 0 || last_calculated == 0) {
      // Initialize buffers
      ArrayInitialize(SSLBuffer, 0);
      ArrayInitialize(SSLColorBuffer, 0);
      ArrayInitialize(BaselineBuffer, 0);
      ArrayInitialize(BaselineColorBuffer, 0);
      ArrayInitialize(ATRUpperBuffer, 0);
      ArrayInitialize(ATRLowerBuffer, 0);
      ArrayInitialize(KeltnerUpperBuffer, 0);
      ArrayInitialize(KeltnerLowerBuffer, 0);
      ArrayInitialize(ATRBuffer, 0);
      ArrayInitialize(RangeMABuffer, 0);
      ArrayInitialize(HMAHighBuffer, 0);
      ArrayInitialize(HMALowBuffer, 0);
      ArrayInitialize(DirectionBuffer, 0);
      
      // Calculate full HMA history
      CalculateHMA(high, SSL_Period, SSL_Period, rates_total-1, HMAHighBuffer, MA_Method);
      CalculateHMA(low, SSL_Period, SSL_Period, rates_total-1, HMALowBuffer, MA_Method);
      CalculateHMA(close, SSL_Period, SSL_Period, rates_total-1, BaselineBuffer, MA_Method);
      
      start = SSL_Period;
      
      // Clear any bar coloring objects
      if(Color_Bars) {
         ObjectsDeleteAll(0, "SSLBarColor_");
      }
   } else {
      // Only update from last calculated bar
      start = MathMax(prev_calculated - 5, SSL_Period); // Recalculate a few bars back for accuracy
      
      // Calculate only for new bars - Efficient incremental calculation
      if(start < rates_total) {
         CalculateHMA(high, SSL_Period, start, rates_total-1, HMAHighBuffer, MA_Method);
         CalculateHMA(low, SSL_Period, start, rates_total-1, HMALowBuffer, MA_Method);
         CalculateHMA(close, SSL_Period, start, rates_total-1, BaselineBuffer, MA_Method);
      }
   }
   
   // Copy ATR values - use buffer time range for efficiency
   if(CopyBuffer(atrHandle, 0, 0, rates_total, ATRBuffer) <= 0) {
      Print("Error copying ATR data: ", GetLastError());
      return 0;
   }
   
   // Clean up old bar coloring objects for performance
   if(Color_Bars && (rates_total > 1000) && (prev_calculated > 0)) {
      // Lấy số lượng thanh hiển thị dưới dạng long
      long visible_bars_long = ChartGetInteger(0, CHART_VISIBLE_BARS);
      
      // Kiểm tra giới hạn trước khi ép kiểu
      int visible_bars;
      if(visible_bars_long > INT_MAX) {
         visible_bars = INT_MAX; // Giới hạn ở giá trị tối đa của int
         Print("Cảnh báo: Số thanh hiển thị vượt quá giới hạn int, giới hạn ở INT_MAX");
      }
      else {
         visible_bars = (int)visible_bars_long; // Ép kiểu an toàn
      }
      
      // Gọi hàm dọn dẹp với giá trị đã kiểm tra
      CleanupOldBarObjects(time, visible_bars);
   }
   
   // Main calculation loop - only process necessary bars
   for(int i = start; i < rates_total && !IsStopped(); i++) {
      // Calculate ATR bands
      ATRUpperBuffer[i] = close[i] + ATRBuffer[i] * ATR_Multiplier;
      ATRLowerBuffer[i] = close[i] - ATRBuffer[i] * ATR_Multiplier;
      
      // Calculate True Range for Keltner Channel - standard TR formula
      double tr = high[i] - low[i];
      if(i > 0) {
         double trueHigh = MathMax(high[i], close[i-1]);
         double trueLow = MathMin(low[i], close[i-1]);
         tr = trueHigh - trueLow;
      }
      
      // Calculate EMA of True Range for Keltner Channel
      if(i == start) {
         RangeMABuffer[i] = tr;
      } else {
         double alpha = 2.0 / (SSL_Period + 1.0);
         RangeMABuffer[i] = alpha * tr + (1 - alpha) * RangeMABuffer[i-1];
      }
      
      // Calculate Keltner Channel (exactly like TradingView)
      KeltnerUpperBuffer[i] = BaselineBuffer[i] + RangeMABuffer[i] * Keltner_Multiplier;
      KeltnerLowerBuffer[i] = BaselineBuffer[i] - RangeMABuffer[i] * Keltner_Multiplier;
      
      // Process SSL direction - Tradingview-style logic
      if(i == start) {
         // Initialize direction on first bar
         if(close[i] > HMAHighBuffer[i])
            DirectionBuffer[i] = 1;       // Bullish
         else if(close[i] < HMALowBuffer[i])
            DirectionBuffer[i] = -1;      // Bearish
         else
            DirectionBuffer[i] = 0;       // Neutral
      } else {
         // Inherit previous direction
         DirectionBuffer[i] = DirectionBuffer[i-1];
         
         // Check for direction change - exact TradingView logic
         if(close[i] > HMAHighBuffer[i])
            DirectionBuffer[i] = 1;       // Change to bullish
         else if(close[i] < HMALowBuffer[i])
            DirectionBuffer[i] = -1;      // Change to bearish
      }
      
      // Set SSL value and color based on direction
      if(DirectionBuffer[i] > 0) {
         SSLBuffer[i] = HMALowBuffer[i];    // Bullish - use low line
         SSLColorBuffer[i] = 1;             // Bullish color (blue)
      } else if(DirectionBuffer[i] < 0) {
         SSLBuffer[i] = HMAHighBuffer[i];   // Bearish - use high line
         SSLColorBuffer[i] = 2;             // Bearish color (magenta)
      } else {
         SSLBuffer[i] = (HMAHighBuffer[i] + HMALowBuffer[i]) / 2;  // Neutral
         SSLColorBuffer[i] = 0;             // Neutral color (gray)
      }
      
      // Set Baseline color exactly like TradingView (using Keltner position)
      if(close[i] > KeltnerUpperBuffer[i])
         BaselineColorBuffer[i] = 1;     // Bullish (blue)
      else if(close[i] < KeltnerLowerBuffer[i])
         BaselineColorBuffer[i] = 2;     // Bearish (magenta)
      else
         BaselineColorBuffer[i] = 0;     // Neutral (gray)
      
      // Color chart bars for recent visible bars only (performance optimization)
      if(Color_Bars && i >= rates_total - Max_Colored_Bars) {
         string objName = "SSLBarColor_" + TimeToString(time[i]);
         
         // Remove any existing object with this name
         ObjectDelete(0, objName);
         
         // Determine end time for rectangle
         datetime timeEnd;
         if(i < rates_total - 1)
            timeEnd = time[i+1];
         else
            timeEnd = time[i] + PeriodSeconds();
         
         // Create colored rectangle behind bar - EXACT TRADINGVIEW LOGIC
         if(close[i] > KeltnerUpperBuffer[i]) {
            // Bullish bar - blue background (same as Baseline coloring logic)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time[i], low[i] - ATRBuffer[i]*0.2, 
                        timeEnd, high[i] + ATRBuffer[i]*0.2);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, C'0,195,255,5');  // #00c3ff with 5% opacity
            ObjectSetInteger(0, objName, OBJPROP_FILL, true);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
         } 
         else if(close[i] < KeltnerLowerBuffer[i]) {
            // Bearish bar - magenta background (same as Baseline coloring logic)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time[i], low[i] - ATRBuffer[i]*0.2, 
                        timeEnd, high[i] + ATRBuffer[i]*0.2);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, C'255,0,98,5');  // #ff0062 with 5% opacity
            ObjectSetInteger(0, objName, OBJPROP_FILL, true);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
         }
         else {
            // Neutral bar - gray background (same as Baseline coloring logic)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time[i], low[i] - ATRBuffer[i]*0.2, 
                        timeEnd, high[i] + ATRBuffer[i]*0.2);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, C'128,128,128,5');  // Gray with 5% opacity
            ObjectSetInteger(0, objName, OBJPROP_FILL, true);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
         }
      }
   }
   
   // Update calculation tracking
   last_calculated = rates_total;
   
   // Return value of prev_calculated for next call
   return(rates_total);
}