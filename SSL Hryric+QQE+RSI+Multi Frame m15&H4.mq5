//+------------------------------------------------------------------+
//|                                                   EA_Scaping.mq5 |
//|                        Copyright 2023, Your Company              |
//|                                     http://www.yourcompany.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Company"
#property link      "http://www.yourcompany.com"
#property version   "1.03"

// ===== CẢI TIẾN 1: Enum cho chỉ số cache, tăng khả năng đọc và bảo trì =====
// Enum cho cache chỉ báo H4
enum ENUM_H4_CACHE_INDEX {
    H4_SSL_UPPER_IDX,     // 0 - Upper SSL line (green)
    H4_SSL_LOWER_IDX,     // 1 - Lower SSL line (red)
    H4_ADX_MAIN_IDX,      // 2 - ADX main line
    H4_ADX_PLUS_IDX,      // 3 - +DI line
    H4_ADX_MINUS_IDX,     // 4 - -DI line
    H4_EMA200_IDX,        // 5 - EMA 200 value
    H4_CACHE_SIZE         // 6 - Size of the cache
};

// Enum cho cache chỉ báo M15
enum ENUM_M15_CACHE_INDEX {
    M15_SSL_UPPER_IDX,    // 0 - Upper SSL line (green)
    M15_SSL_LOWER_IDX,    // 1 - Lower SSL line (red)
    M15_QQE_VALUE_IDX,    // 2 - QQE main value
    M15_QQE_COLOR_IDX,    // 3 - QQE color value
    M15_RSI_IDX,          // 4 - Current RSI value
    M15_RSI1_IDX,         // 5 - RSI value 1 bar ago
    M15_RSI2_IDX,         // 6 - RSI value 2 bars ago
    M15_EMA200_IDX,       // 7 - EMA 200 value
    M15_ATR_IDX,          // 8 - ATR value
    M15_BBW_IDX,          // 9 - Bollinger Band Width value
    M15_CACHE_SIZE        // 10 - Size of the cache
};

// ===== CẢI TIẾN 2: Hàm iBufCount để kiểm tra số lượng buffer của chỉ báo =====
int iBufCount(int handle) {
    for(int i=0; i<100; i++) {
        double test[];
        if(CopyBuffer(handle, i, 0, 1, test) < 0) {
            return i;
        }
    }
    return 100;  // Return the maximum number of buffers checked if all checks succeed
}

// Include necessary libraries
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayString.mqh>

// Input parameters for the EA
input group "===== EA Configuration ====="
input string EA_Name = "EA Scaping";
input bool   Enable_Trading = true;       // Enable/disable trading
input int    MagicNumber = 123456;        // Unique identifier for this EA's trades
input double Risk_Percent = 1.0;          // Risk percentage per trade (1.0 = 1%)
input double Max_Daily_Risk = 3.0;        // Maximum daily risk (3.0 = 3%)
input int    Max_Positions = 2;           // Maximum number of open positions
input int    Max_Consecutive_Losses = 3;  // Maximum consecutive losses before pausing
input bool   Use_State_Persistence = true; // Store position states in comments

// ===== CẢI TIẾN 4: Tham số hóa giá trị deviation =====
input group "===== Order Execution Settings ====="
input int    Deviation_Points = 10;       // Initial price deviation in points
input int    Retry_Deviation_Points = 20; // Retry price deviation in points

input group "===== MTF Settings ====="
input bool   Use_MTF = true;              // Use Multi-timeframe analysis
input ENUM_TIMEFRAMES Trend_Timeframe = PERIOD_H4;  // Timeframe for trend analysis
input ENUM_TIMEFRAMES Entry_Timeframe = PERIOD_M15; // Timeframe for entry signals

input group "===== Indicator Settings ====="
input int    SSL_Period_H4 = 60;          // SSL Hybrid period for H4
input int    SSL_Period_M15 = 30;         // SSL Hybrid period for M15
input int    QQE_Period = 14;             // QQE Period
input double QQE_SF = 5.0;                // QQE Smoothing Factor
input double QQE_Fast = 2.618;            // QQE Fast Period
input double QQE_Slow = 4.236;            // QQE Slow Period

// ===== THÊM MỚI: Tham số hóa buffer và giá trị QQE =====
input int    QQE_Color_Buffer_Index = 3;  // Buffer index for QQE color (default: 3)
input double QQE_Bullish_Color_Value = 1; // Value when QQE indicates bullish (default: 1)
input double QQE_Bearish_Color_Value = -1; // Value when QQE indicates bearish (default: -1)

input int    RSI_Period = 14;             // RSI Period
input int    ADX_Period = 14;             // ADX Period
input int    EMA_Period = 200;            // EMA Period
input int    BBW_Period = 20;             // Bollinger Bands Width Period
input double BBW_Deviation = 2.0;         // Bollinger Bands Width Deviation
input int    ATR_Period = 14;             // ATR Period

input group "===== Entry Rules ====="
input double ADX_Threshold = 25.0;        // ADX threshold for trend strength
input double BBW_ATR_Multiplier = 1.5;    // BBW/ATR multiplier for volatility filter
input int    RSI_Lookback_Bars = 10;      // Bars to look back for RSI extremes
input double RSI_Oversold = 30.0;         // RSI oversold threshold
input double RSI_Overbought = 70.0;       // RSI overbought threshold

input group "===== Exit Rules ====="
input double SL_ATR_Multiplier_M15 = 1.5; // Stop loss ATR multiplier for M15
input double SL_ATR_Multiplier_H4 = 2.0;  // Stop loss ATR multiplier for H4
input double TP1_R_Multiplier = 1.5;      // First target (R multiple)
input double TP2_R_Multiplier = 2.5;      // Second target (R multiple)
input double TP1_Position_Size = 30.0;    // Percentage to close at first target
input double TP2_Position_Size = 30.0;    // Percentage to close at second target

input group "===== News Filter Settings ====="
input bool   Use_News_Filter = true;      // Use news filter
input bool   Use_Calendar_API = true;     // Use Calendar API for news
input bool   Use_Fixed_Hours = true;      // Use fixed hours as fallback
input int    News_Importance = 3;         // Minimum news importance (1-3)
input int    News_Before_Minutes = 30;    // Stop trading minutes before news
input int    News_After_Minutes = 15;     // Stop trading minutes after news
input int    GMT_Offset = 7;              // GMT Offset for your timezone (Vietnam = +7)

// ===== CẢI TIẾN 6: Xử lý múi giờ với DST =====
input int    DST_Offset = 0;              // Add 1 during Daylight Saving Time periods

// ===== THÊM MỚI: Tham số cấp độ logging =====
enum ENUM_LOG_LEVEL {
    LOG_ERROR = 0,    // Only errors
    LOG_WARNING = 1,  // Errors and warnings
    LOG_INFO = 2,     // Normal information
    LOG_DEBUG = 3     // Detailed debug info
};
input ENUM_LOG_LEVEL Log_Level = LOG_INFO; // Logging level

// ===== THÊM MỚI: Tham số tần suất báo cáo hiệu suất =====
input int    Log_Summary_Frequency = 5;    // Performance summary log frequency (0 = disable)

// Global variables
CTrade trade;                          // Trading object
datetime nextNewsUpdate;               // Time for next news update
int h4_ssl_handle;                     // Handle for SSL Hybrid H4
int m15_ssl_handle;                    // Handle for SSL Hybrid M15
int h4_adx_handle;                     // Handle for ADX H4
int m15_qqe_handle;                    // Handle for QQE M15
int m15_rsi_handle;                    // Handle for RSI M15
int h4_ema_handle;                     // Handle for EMA200 H4
int m15_ema_handle;                    // Handle for EMA200 M15
int m15_atr_handle;                    // Handle for ATR M15
int m15_bbw_handle;                    // Handle for Bollinger Bands M15
bool isInitialized = false;            // Initialization flag
EAScaping* ea = NULL;                  // Main EA object

// ===== THÊM MỚI: Logging function =====
void LogMessage(ENUM_LOG_LEVEL level, string message) {
    if(level <= Log_Level) {
        string levelText = "";
        switch(level) {
            case LOG_ERROR: levelText = "ERROR"; break;
            case LOG_WARNING: levelText = "WARNING"; break;
            case LOG_INFO: levelText = "INFO"; break;
            case LOG_DEBUG: levelText = "DEBUG"; break;
        }
        Print(TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " [", levelText, "] ", message);
    }
}

//+------------------------------------------------------------------+
//| Structure for fixed news time ranges                             |
//+------------------------------------------------------------------+
struct TimeRange {
    int dayOfWeek;       // 0-6, 0 = Sunday
    int startHour;       // 0-23
    int startMinute;     // 0-59
    int endHour;         // 0-23
    int endMinute;       // 0-59
};

//+------------------------------------------------------------------+
//| Structure for news events                                         |
//+------------------------------------------------------------------+
struct NewsEvent {
    datetime time;       // Event time
    string currency;     // Related currency
    string name;         // Event name
    int importance;      // Importance (1-3)
};

//+------------------------------------------------------------------+
//| Structure for position tracking                                   |
//+------------------------------------------------------------------+
class PositionInfo {
public:
    ulong ticket;        // Position ticket
    double openPrice;    // Open price
    double stopLoss;     // Initial stop loss
    double volume;       // Original volume
    bool tp1_hit;        // TP1 hit flag
    bool tp2_hit;        // TP2 hit flag
    bool trail_with_ssl; // Trail with SSL flag
};

// Forward declaration for EAScaping class
class EAScaping;

//+------------------------------------------------------------------+
//| Observer Interface for Multi-timeframe                            |
//+------------------------------------------------------------------+
class TrendObserver {
public:
    virtual void OnTrendChanged(int newTrend, datetime trendTime) = 0;
};

//+------------------------------------------------------------------+
//| Enhanced error handling for trade operations                      |
//+------------------------------------------------------------------+
string GetTradeErrorDescription(int error_code) {
    switch(error_code) {
        case 10004: return "Requote";
        case 10006: return "Order rejected";
        case 10007: return "Order canceled by trader";
        case 10008: return "Order canceled by dealer";
        case 10009: return "Order placed";
        case 10010: return "Only part of the order was executed";
        case 10011: return "Error placing order";
        case 10012: return "Request canceled";
        case 10013: return "Invalid order fills";
        case 10014: return "Invalid order expiration";
        case 10015: return "Invalid order price";
        case 10016: return "Invalid stops";
        case 10017: return "Trade not allowed";
        case 10018: return "Market closed";
        case 10019: return "Not enough money";
        case 10020: return "Prices changed";
        case 10021: return "No quotes to process request";
        case 10022: return "Invalid expiration date in the order request";
        case 10023: return "Order state changed";
        case 10024: return "Too many requests";
        case 10025: return "No changes in request";
        case 10026: return "Autotrading disabled by server";
        case 10027: return "Autotrading disabled by client terminal";
        case 10028: return "Request locked for processing";
        case 10029: return "Order or position frozen";
        case 10030: return "Invalid order filling type";
        case 10031: return "Connection";
        case 10032: return "Only connection";
        case 10033: return "Limit orders only allowed";
        case 10034: return "Reached limit of orders and positions";
        default: return "Error #" + IntegerToString(error_code);
    }
}

//+------------------------------------------------------------------+
//| Indicator Cache Class                                            |
//+------------------------------------------------------------------+
class IndicatorCache {
private:
    struct CachedData {
        datetime updateTime;
        double values[M15_CACHE_SIZE]; // UPDATED: Using enum size constant
        bool isValid;
    };
    
    CachedData h4_data;
    CachedData m15_data;
    int failedUpdateCount;
    const int MAX_FAILED_UPDATES;
    
public:
    IndicatorCache() : failedUpdateCount(0), MAX_FAILED_UPDATES(5) {
        h4_data.isValid = false;
        m15_data.isValid = false;
        
        // Ensure array sizes are adequate - REMOVED: Not needed for fixed-size arrays
        // ArrayResize(h4_data.values, H4_CACHE_SIZE);
        // ArrayResize(m15_data.values, M15_CACHE_SIZE);
    }
    
    bool Init() {
        ResetCache();
        return true;
    }
    
    void ResetCache() {
        h4_data.isValid = false;
        m15_data.isValid = false;
        failedUpdateCount = 0;
    }
    
    bool UpdateH4Data() {
        datetime currentH4Time = iTime(Symbol(), PERIOD_H4, 0);
        
        if(!h4_data.isValid || currentH4Time != h4_data.updateTime) {
            if(!FetchH4Data(h4_data.values)) {
                failedUpdateCount++;
                if(failedUpdateCount > MAX_FAILED_UPDATES) {
                    LogMessage(LOG_ERROR, StringFormat("Critical error: Failed to update H4 indicator data %d times consecutively", failedUpdateCount));
                    // Consider additional safety measures here
                }
                return false;
            }
            
            h4_data.updateTime = currentH4Time;
            h4_data.isValid = true;
            failedUpdateCount = 0; // Reset counter on successful update
        }
        
        return h4_data.isValid;
    }
    
    bool UpdateM15Data() {
        datetime currentM15Time = iTime(Symbol(), PERIOD_M15, 0);
        
        if(!m15_data.isValid || currentM15Time != m15_data.updateTime) {
            if(!FetchM15Data(m15_data.values)) {
                failedUpdateCount++;
                if(failedUpdateCount > MAX_FAILED_UPDATES) {
                    LogMessage(LOG_ERROR, StringFormat("Critical error: Failed to update M15 indicator data %d times consecutively", failedUpdateCount));
                    // Consider additional safety measures here
                }
                return false;
            }
            
            m15_data.updateTime = currentM15Time;
            m15_data.isValid = true;
            failedUpdateCount = 0; // Reset counter on successful update
        }
        
        return m15_data.isValid;
    }
    
    double GetH4Value(ENUM_H4_CACHE_INDEX valueIndex) {
        if(valueIndex >= 0 && valueIndex < H4_CACHE_SIZE && h4_data.isValid) {
            return h4_data.values[valueIndex];
        }
        return 0;
    }
    
    double GetM15Value(ENUM_M15_CACHE_INDEX valueIndex) {
        if(valueIndex >= 0 && valueIndex < M15_CACHE_SIZE && m15_data.isValid) {
            return m15_data.values[valueIndex];
        }
        return 0;
    }
    
private:
    bool FetchH4Data(double &values[]) {
        // Fetch required indicator values for H4 timeframe
        double ssl_upper[1], ssl_lower[1];
        double adx_main[1], adx_plus[1], adx_minus[1];
        double ema[1];
        
        if(CopyBuffer(h4_ssl_handle, 0, 1, 1, ssl_upper) != 1 ||
           CopyBuffer(h4_ssl_handle, 1, 1, 1, ssl_lower) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying SSL Hybrid H4 data: %d", GetLastError()));
            return false;
        }
        
        if(CopyBuffer(h4_adx_handle, 0, 1, 1, adx_main) != 1 ||
           CopyBuffer(h4_adx_handle, 1, 1, 1, adx_plus) != 1 ||
           CopyBuffer(h4_adx_handle, 2, 1, 1, adx_minus) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying ADX H4 data: %d", GetLastError()));
            return false;
        }
        
        if(CopyBuffer(h4_ema_handle, 0, 1, 1, ema) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying EMA H4 data: %d", GetLastError()));
            return false;
        }
        
        // Store values in the array using the enum indices
        values[H4_SSL_UPPER_IDX] = ssl_upper[0];
        values[H4_SSL_LOWER_IDX] = ssl_lower[0];
        values[H4_ADX_MAIN_IDX] = adx_main[0];
        values[H4_ADX_PLUS_IDX] = adx_plus[0];
        values[H4_ADX_MINUS_IDX] = adx_minus[0];
        values[H4_EMA200_IDX] = ema[0];
        
        return true;
    }
    
    bool FetchM15Data(double &values[]) {
        // Fetch required indicator values for M15 timeframe
        double ssl_upper[1], ssl_lower[1];
        double qqe_value[1], qqe_color[1];
        double rsi[1], rsi1[1], rsi2[1];
        double ema[1];
        double atr[1];
        
        // FIXED: Proper calculation of Bollinger Bands Width
        double bb_upper[1], bb_lower[1], bb_middle[1];
        
        if(CopyBuffer(m15_ssl_handle, 0, 1, 1, ssl_upper) != 1 ||
           CopyBuffer(m15_ssl_handle, 1, 1, 1, ssl_lower) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying SSL Hybrid M15 data: %d", GetLastError()));
            return false;
        }
        
        // UPDATED: Using configurable QQE buffer index
        if(CopyBuffer(m15_qqe_handle, 0, 1, 1, qqe_value) != 1 ||
           CopyBuffer(m15_qqe_handle, QQE_Color_Buffer_Index, 1, 1, qqe_color) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying QQE M15 data: %d", GetLastError()));
            return false;
        }
        
        if(CopyBuffer(m15_rsi_handle, 0, 0, 1, rsi) != 1 ||
           CopyBuffer(m15_rsi_handle, 0, 1, 1, rsi1) != 1 ||
           CopyBuffer(m15_rsi_handle, 0, 2, 1, rsi2) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying RSI M15 data: %d", GetLastError()));
            return false;
        }
        
        if(CopyBuffer(m15_ema_handle, 0, 1, 1, ema) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying EMA M15 data: %d", GetLastError()));
            return false;
        }
        
        if(CopyBuffer(m15_atr_handle, 0, 1, 1, atr) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying ATR M15 data: %d", GetLastError()));
            return false;
        }
        
        // FIXED: Correctly get Bollinger Bands data to calculate width
        if(CopyBuffer(m15_bbw_handle, 0, 1, 1, bb_middle) != 1 ||
           CopyBuffer(m15_bbw_handle, 1, 1, 1, bb_upper) != 1 ||
           CopyBuffer(m15_bbw_handle, 2, 1, 1, bb_lower) != 1) {
            LogMessage(LOG_ERROR, StringFormat("Error copying BBW M15 data: %d", GetLastError()));
            return false;
        }
        
        // Store values in the array using the enum indices
        values[M15_SSL_UPPER_IDX] = ssl_upper[0];
        values[M15_SSL_LOWER_IDX] = ssl_lower[0];
        values[M15_QQE_VALUE_IDX] = qqe_value[0];
        values[M15_QQE_COLOR_IDX] = qqe_color[0];
        values[M15_RSI_IDX] = rsi[0];
        values[M15_RSI1_IDX] = rsi1[0];
        values[M15_RSI2_IDX] = rsi2[0];
        values[M15_EMA200_IDX] = ema[0];
        values[M15_ATR_IDX] = atr[0];
        
        // FIXED: Calculate Bollinger Bands Width correctly
        values[M15_BBW_IDX] = bb_upper[0] - bb_lower[0]; // Absolute width
        
        return true;
    }
};

//+------------------------------------------------------------------+
//| H4 Trend Analyzer Class                                          |
//+------------------------------------------------------------------+
class H4TrendAnalyzer {
private:
    IndicatorCache* cache;
    int currentTrend;           // 1 = up, -1 = down, 0 = neutral
    datetime lastUpdateTime;
    CArrayObj observers;

public:
    H4TrendAnalyzer(IndicatorCache* indicator_cache) {
        cache = indicator_cache;
        currentTrend = 0;
        lastUpdateTime = 0;
        
        // FIXED: Properly configure CArrayObj for memory management
        observers.FreeMode(true);
    }

    ~H4TrendAnalyzer() {
        observers.Clear();
    }
    
    void AddObserver(TrendObserver* observer) {
        observers.Add(observer);
    }
    
    void Update(bool updateCache = true) {
        datetime newCandle = iTime(Symbol(), PERIOD_H4, 0);
        
        // Check if we have a new H4 candle
        if(newCandle != lastUpdateTime) {
            // Update the cache if requested
            if(updateCache && !cache->UpdateH4Data()) {
                LogMessage(LOG_ERROR, "Failed to update H4 data cache");
                return;
            }
            
            // Calculate the current trend
            int newTrend = CalculateTrend();
            
            // If trend has changed, notify observers
            if(newTrend != currentTrend) {
                currentTrend = newTrend;
                NotifyObservers();
            }
            
            lastUpdateTime = newCandle;
        }
    }
    
    int GetTrend() {
        return currentTrend;
    }
    
private:
    int CalculateTrend() {
        // Get values from cache using enum indices for clarity
        double ssl_upper = cache->GetH4Value(H4_SSL_UPPER_IDX);
        double ssl_lower = cache->GetH4Value(H4_SSL_LOWER_IDX);
        double adx = cache->GetH4Value(H4_ADX_MAIN_IDX);
        double di_plus = cache->GetH4Value(H4_ADX_PLUS_IDX);
        double di_minus = cache->GetH4Value(H4_ADX_MINUS_IDX);
        double ema200 = cache->GetH4Value(H4_EMA200_IDX);
        
        double close = iClose(Symbol(), PERIOD_H4, 1);
        
        // Check if ADX is strong enough
        if(adx < ADX_Threshold) {
            return 0;  // No clear trend
        }
        
        // Determine trend direction
        if(ssl_upper > ssl_lower && close > ema200 && di_plus > di_minus) {
            return 1;  // Uptrend
        }
        else if(ssl_upper < ssl_lower && close < ema200 && di_plus < di_minus) {
            return -1; // Downtrend
        }
        
        return 0;  // No clear trend
    }
    
    void NotifyObservers() {
        for(int i = 0; i < observers.Total(); i++) {
            TrendObserver* observer = (TrendObserver*)observers.At(i);
            if(observer != NULL) {
                observer->OnTrendChanged(currentTrend, lastUpdateTime);
            }
        }
    }
};

//+------------------------------------------------------------------+
//| M15 Entry Finder Class (Observer)                                |
//+------------------------------------------------------------------+
class M15EntryFinder : public TrendObserver {
private:
    IndicatorCache* cache;
    int h4Trend;
    datetime h4TrendTime;
    
public:
    M15EntryFinder(IndicatorCache* indicator_cache) {
        cache = indicator_cache;
        h4Trend = 0;
        h4TrendTime = 0;
    }
    
    // Implementation of TrendObserver interface
    virtual void OnTrendChanged(int newTrend, datetime trendTime) {
        h4Trend = newTrend;
        h4TrendTime = trendTime;
        
        LogMessage(LOG_INFO, StringFormat("H4 trend changed to: %s", 
                  (newTrend == 1 ? "Uptrend" : (newTrend == -1 ? "Downtrend" : "Neutral"))));
    }
    
    void Update(bool updateCache = true) {
        // Update M15 data cache if requested
        if(updateCache && !cache->UpdateM15Data()) {
            LogMessage(LOG_ERROR, "Failed to update M15 data cache");
            return;
        }
    }
    
    bool CheckBuySignal() {
        // If not in uptrend on H4, no buy signal
        if(h4Trend != 1) {
            return false;
        }
        
        // Get values from cache using enum indices for clarity
        double ssl_upper = cache->GetM15Value(M15_SSL_UPPER_IDX);
        double ssl_lower = cache->GetM15Value(M15_SSL_LOWER_IDX);
        double qqe_value = cache->GetM15Value(M15_QQE_VALUE_IDX);
        double qqe_color = cache->GetM15Value(M15_QQE_COLOR_IDX);
        double rsi = cache->GetM15Value(M15_RSI_IDX);
        double rsi1 = cache->GetM15Value(M15_RSI1_IDX);
        double rsi2 = cache->GetM15Value(M15_RSI2_IDX);
        double ema200 = cache->GetM15Value(M15_EMA200_IDX);
        double atr = cache->GetM15Value(M15_ATR_IDX);
        double bbw = cache->GetM15Value(M15_BBW_IDX);
        
        double close = iClose(Symbol(), PERIOD_M15, 1);
        
        // Check M15 conditions
        bool m15Above200EMA = close > ema200;
        bool sslBullish = (ssl_upper > ssl_lower);
        
        // UPDATED: Using configurable QQE color values
        bool qqePositive = (qqe_value > 0 && qqe_color == QQE_Bullish_Color_Value);
        
        // Check RSI conditions
        bool rsiAbove50 = (rsi > 50);
        bool rsiRising = (rsi > rsi1 && rsi1 > rsi2);
        bool touchedOversold = false;
        
        // Check if RSI touched oversold in recent bars
        for(int i = 0; i < RSI_Lookback_Bars; i++) {
            double pastRsi = iRSI(Symbol(), PERIOD_M15, RSI_Period, PRICE_CLOSE, i);
            if(pastRsi < RSI_Oversold) {
                touchedOversold = true;
                break;
            }
        }
        
        // Check volatility
        bool volatilityOK = (bbw > BBW_ATR_Multiplier * atr);
        
        // Combine all conditions
        return m15Above200EMA && sslBullish && qqePositive && 
               rsiAbove50 && rsiRising && touchedOversold && volatilityOK;
    }
    
    bool CheckSellSignal() {
        // If not in downtrend on H4, no sell signal
        if(h4Trend != -1) {
            return false;
        }
        
        // Get values from cache using enum indices for clarity
        double ssl_upper = cache->GetM15Value(M15_SSL_UPPER_IDX);
        double ssl_lower = cache->GetM15Value(M15_SSL_LOWER_IDX);
        double qqe_value = cache->GetM15Value(M15_QQE_VALUE_IDX);
        double qqe_color = cache->GetM15Value(M15_QQE_COLOR_IDX);
        double rsi = cache->GetM15Value(M15_RSI_IDX);
        double rsi1 = cache->GetM15Value(M15_RSI1_IDX);
        double rsi2 = cache->GetM15Value(M15_RSI2_IDX);
        double ema200 = cache->GetM15Value(M15_EMA200_IDX);
        double atr = cache->GetM15Value(M15_ATR_IDX);
        double bbw = cache->GetM15Value(M15_BBW_IDX);
        
        double close = iClose(Symbol(), PERIOD_M15, 1);
        
        // Check M15 conditions
        bool m15Below200EMA = close < ema200;
        bool sslBearish = (ssl_upper < ssl_lower);
        
        // UPDATED: Using configurable QQE color values
        bool qqeNegative = (qqe_value < 0 && qqe_color == QQE_Bearish_Color_Value);
        
        // Check RSI conditions
        bool rsiBelow50 = (rsi < 50);
        bool rsiFalling = (rsi < rsi1 && rsi1 < rsi2);
        bool touchedOverbought = false;
        
        // Check if RSI touched overbought in recent bars
        for(int i = 0; i < RSI_Lookback_Bars; i++) {
            double pastRsi = iRSI(Symbol(), PERIOD_M15, RSI_Period, PRICE_CLOSE, i);
            if(pastRsi > RSI_Overbought) {
                touchedOverbought = true;
                break;
            }
        }
        
        // Check volatility
        bool volatilityOK = (bbw > BBW_ATR_Multiplier * atr);
        
        // Combine all conditions
        return m15Below200EMA && sslBearish && qqeNegative && 
               rsiBelow50 && rsiFalling && touchedOverbought && volatilityOK;
    }
    
    int GetH4Trend() {
        return h4Trend;
    }
};

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class RiskManager {
private:
    double riskPercent;
    double maxDailyRisk;
    double dailyLoss;
    int consecutiveLosses;
    int maxConsecutiveLosses;
    datetime lastResetDay; // Added: Track the last day reset was done
    
public:
    RiskManager(double risk = 1.0, double maxDaily = 3.0, int maxConsLosses = 3) 
        : riskPercent(risk), maxDailyRisk(maxDaily), dailyLoss(0), 
          consecutiveLosses(0), maxConsecutiveLosses(maxConsLosses), lastResetDay(0) {} // Initialize lastResetDay
    
    void Reset() {
        datetime currentDayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
        
        // Check if it's a new day compared to the last reset
        if(currentDayStart != lastResetDay) {
            // Reset daily values at the start of a new day
            LogMessage(LOG_INFO, StringFormat("New trading day detected. Resetting daily loss (was %.2f%%) and consecutive losses (was %d).", dailyLoss, consecutiveLosses));
            dailyLoss = 0;
            // Reset consecutive losses as well at the start of a new day
            consecutiveLosses = 0; 
            lastResetDay = currentDayStart;
        }
    }
    
    double CalculateLotSize(double stopDistance) {
        // Get account info
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * riskPercent / 100.0;
        double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        
        // Calculate number of pips for SL
        double pipValue = stopDistance / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        
        // Calculate lot size
        double lotSize = riskAmount / (pipValue * tickValue / tickSize);
        
        // Round and limit lot size
        double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
        
        lotSize = MathFloor(lotSize / lotStep) * lotStep;
        lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
        
        return lotSize;
    }
    
    bool CanOpenPosition() {
        // Check if we're within daily risk limit
        if(dailyLoss >= maxDailyRisk) {
            LogMessage(LOG_WARNING, StringFormat("Daily loss limit reached: %.2f%%. Max: %.2f%%", dailyLoss, maxDailyRisk));
            return false;
        }
        
        // Check if we have too many consecutive losses
        if(consecutiveLosses >= maxConsecutiveLosses) {
            LogMessage(LOG_WARNING, StringFormat("Too many consecutive losses: %d", consecutiveLosses));
            return false;
        }
        
        // Check if we have too many positions open
        if(PositionsTotal() >= Max_Positions) {
            LogMessage(LOG_WARNING, StringFormat("Maximum positions reached: %d/%d", PositionsTotal(), Max_Positions));
            return false;
        }
        
        return true;
    }
    
    void UpdateStats(bool isWin, double profitPercent) {
        if(isWin) {
            consecutiveLosses = 0;
            LogMessage(LOG_INFO, StringFormat("Risk stats updated: Win, consecutive losses reset to 0"));
        }
        else {
            consecutiveLosses++;
            dailyLoss += MathAbs(profitPercent);
            LogMessage(LOG_INFO, StringFormat("Risk stats updated: Loss, consecutive losses: %d, daily loss: %.2f%%", 
                     consecutiveLosses, dailyLoss));
        }
    }
};

//+------------------------------------------------------------------+
//| News Filter Class                                                |
//+------------------------------------------------------------------+
class NewsFilter {
private:
    string currencies[2];                   // Currency pair components
    ENUM_CALENDAR_EVENT_IMPORTANCE minImportance; // Min news importance
    int lookAheadMinutes;                   // Minutes before news
    int lookBackMinutes;                    // Minutes after news
    datetime nextCheckTime;                 // Next check time
    bool useCalendarAPI;                    // Use Calendar API
    bool useFixedHours;                     // Use fixed hours
    CArrayObj upcomingEvents;               // Upcoming news events
    CArrayObj fixedNewsRanges;              // Fixed news times
    int gmtOffset;                          // GMT offset for time zone
    int dstOffset;                          // DST offset adjustment
    
public:
    NewsFilter(bool useAPI = true, bool useFixed = false, 
              int importance = 3, int gmt = 0, int dst = 0) {
        // Extract currencies from symbol
        ExtractCurrencies();
        
        // Map importance from input (1-3) to ENUM_CALENDAR_EVENT_IMPORTANCE
        switch(importance) {
            case 1:
                minImportance = CALENDAR_IMPORTANCE_LOW;
                break;
            case 2:
                minImportance = CALENDAR_IMPORTANCE_MODERATE;
                break;
            case 3:
            default:
                minImportance = CALENDAR_IMPORTANCE_HIGH;
                break;
        }
        
        lookAheadMinutes = News_Before_Minutes;
        lookBackMinutes = News_After_Minutes;
        nextCheckTime = 0;
        useCalendarAPI = useAPI;
        useFixedHours = useFixed;
        gmtOffset = gmt;
        dstOffset = dst;
        
        // Initialize arrays with proper memory management
        upcomingEvents.FreeMode(true);
        fixedNewsRanges.FreeMode(true);
        
        // Setup default fixed news times
        SetupDefaultFixedTimes();
    }
    
    ~NewsFilter() {
        // CArrayObj::FreeMode(true) ensures objects are deleted with Clear()
        upcomingEvents.Clear();
        fixedNewsRanges.Clear();
    }
    
    bool IsNewsTime() {
        datetime currentTime = TimeCurrent();
        bool isNewsTimeNow = false;
        
        // Update news events periodically
        if(useCalendarAPI && currentTime >= nextCheckTime) {
            UpdateNewsEvents();
            nextCheckTime = currentTime + 3600; // Check again in 1 hour
        }
        
        // Check if current time is within news window using Calendar API
        if(useCalendarAPI) {
            isNewsTimeNow = IsWithinNewsWindow(currentTime);
            
            // If not news time and we have events (API working), return false
            if(!isNewsTimeNow && upcomingEvents.Total() > 0) {
                return false;
            }
        }
        
        // If API not used or no events found, check fixed times
        if(!useCalendarAPI || useFixedHours || upcomingEvents.Total() == 0) {
            if(IsWithinFixedNewsTime(currentTime)) {
                LogMessage(LOG_INFO, "Trading paused due to Fixed News Time Window");
                return true;
            }
        }
        
        return isNewsTimeNow;
    }
    
private:
    void ExtractCurrencies() {
        string symbol = Symbol();
        currencies[0] = "";
        currencies[1] = "";
        
        // Remove possible suffixes
        int dotPos = StringFind(symbol, ".");
        if(dotPos > 0) {
            symbol = StringSubstr(symbol, 0, dotPos);
        }
        
        // Standard 6-character forex pair
        if(StringLen(symbol) == 6) {
            currencies[0] = StringSubstr(symbol, 0, 3);
            currencies[1] = StringSubstr(symbol, 3, 3);
        }
        // Pair with separator
        else if(StringFind(symbol, "/") > 0) {
            string parts[];
            StringSplit(symbol, '/', parts);
            if(ArraySize(parts) == 2) {
                currencies[0] = parts[0];
                currencies[1] = parts[1];
            }
        }
        // Special cases
        else if(StringFind(symbol, "XAU") >= 0) {
            currencies[0] = "XAU"; // Gold
            if(StringFind(symbol, "USD") >= 0) currencies[1] = "USD";
        }
        else if(StringFind(symbol, "XAG") >= 0) {
            currencies[0] = "XAG"; // Silver
            if(StringFind(symbol, "USD") >= 0) currencies[1] = "USD";
        }
        else if(StringFind(symbol, "OIL") >= 0 || StringFind(symbol, "WTI") >= 0 || 
                StringFind(symbol, "BRENT") >= 0) {
            currencies[0] = "USD"; // Assume USD news affects oil
        }
        
        StringToUpper(currencies[0]);
        StringToUpper(currencies[1]);
        
        LogMessage(LOG_INFO, StringFormat("News Filter Currency Analysis: %s -> Filter for: %s, %s", 
                  Symbol(), currencies[0], currencies[1]));
    }
    
    // ===== CẢI TIẾN 6: Xử lý múi giờ cho tin tức cố định với DST =====
    void SetupDefaultFixedTimes() {
        // Calculate final offset including DST
        int finalOffset = gmtOffset + dstOffset;
        
        // NFP (First Friday of the month) - typically 8:30AM ET (12:30 GMT)
        TimeRange* nfpTime = new TimeRange;
        nfpTime->dayOfWeek = 5;     // Friday
        nfpTime->startHour = 12 + finalOffset; // 12:30 GMT + offset
        nfpTime->startMinute = 30;
        nfpTime->endHour = 14 + finalOffset;   // 14:00 GMT + offset
        nfpTime->endMinute = 0;
        fixedNewsRanges.Add(nfpTime);
        
        // FOMC - typically 2:00PM ET (18:00 GMT)
        TimeRange* fomcTime = new TimeRange;
        fomcTime->dayOfWeek = 4;    // Thursday
        fomcTime->startHour = 18 + finalOffset; // 18:00 GMT + offset
        fomcTime->startMinute = 0;
        fomcTime->endHour = 19 + finalOffset;   // 19:30 GMT + offset
        fomcTime->endMinute = 30;
        fixedNewsRanges.Add(fomcTime);
        
        // US Market Open - 9:30AM ET (13:30 GMT)
        TimeRange* usOpenTime = new TimeRange;
        usOpenTime->dayOfWeek = -1; // Every day (workday check is done separately)
        usOpenTime->startHour = 13 + finalOffset; // 13:30 GMT + offset
        usOpenTime->startMinute = 30;
        usOpenTime->endHour = 14 + finalOffset;   // 14:30 GMT + offset
        usOpenTime->endMinute = 30;
        fixedNewsRanges.Add(usOpenTime);
        
        // Handle hours that might go beyond 24-hour range
        for(int i = 0; i < fixedNewsRanges.Total(); i++) {
            TimeRange* range = (TimeRange*)fixedNewsRanges.At(i);
            
            // Normalize hours
            if(range->startHour >= 24) range->startHour -= 24;
            if(range->endHour >= 24) range->endHour -= 24;
        }
        
        LogMessage(LOG_INFO, StringFormat("Setup %d fixed news time ranges with final offset: %d", 
                   fixedNewsRanges.Total(), finalOffset));
    }
    
    void UpdateNewsEvents() {
        // Clear existing events
        upcomingEvents.Clear();
        
        // Get current time and time 24 hours ahead
        datetime currentTime = TimeCurrent();
        datetime endTime = currentTime + 24*3600;
        
        // Arrays for Calendar API
        MqlCalendarEvent events[];
        MqlCalendarValue values[];
        
        // Get events for each currency
        for(int i = 0; i < ArraySize(currencies); i++) {
            if(currencies[i] == "") continue;
            
            int eventsCount = CalendarEventByCurrency(currencies[i], events);
            if(eventsCount <= 0) {
                LogMessage(LOG_WARNING, StringFormat("No events found for %s. Error: %d", currencies[i], GetLastError()));
                continue;
            }
            
            for(int j = 0; j < eventsCount; j++) {
                // Filter by importance
                if(events[j].importance >= minImportance) {
                    int valuesCount = CalendarValueHistory(values, events[j].id, currentTime - 3600, endTime);
                    
                    if(valuesCount <= 0) continue;
                    
                    for(int k = 0; k < valuesCount; k++) {
                        if(values[k].time >= currentTime - 3600) { // Include events from the last hour
                            NewsEvent* event = new NewsEvent;
                            event->time = values[k].time;
                            event->currency = currencies[i];
                            event->name = events[j].name;
                            event->importance = events[j].importance;
                            
                            upcomingEvents.Add(event);
                        }
                    }
                }
            }
        }
        
        // Sort events by time
        if(upcomingEvents.Total() > 1) {
            SortNewsByTime();
        }
        
        LogMessage(LOG_INFO, StringFormat("Updated %d news events for next 24 hours", upcomingEvents.Total()));
    }
    
    void SortNewsByTime() {
        for(int i = 0; i < upcomingEvents.Total() - 1; i++) {
            for(int j = i + 1; j < upcomingEvents.Total(); j++) {
                NewsEvent* event1 = (NewsEvent*)upcomingEvents.At(i);
                NewsEvent* event2 = (NewsEvent*)upcomingEvents.At(j);
                
                if(event1->time > event2->time) {
                    upcomingEvents.Swap(i, j);
                }
            }
        }
    }
    
    bool IsWithinNewsWindow(datetime currentTime) {
        int ahead = lookAheadMinutes * 60;
        int back = lookBackMinutes * 60;
        
        for(int i = 0; i < upcomingEvents.Total(); i++) {
            NewsEvent* event = (NewsEvent*)upcomingEvents.At(i);
            
            // Check if current time is within the event window
            if(currentTime >= event->time - ahead && currentTime <= event->time + back) {
                LogMessage(LOG_INFO, StringFormat("News time detected: %s, %s (Importance: %d) at %s", 
                           event->currency, event->name, event->importance,
                           TimeToString(event->time, TIME_DATE|TIME_MINUTES)));
                return true;
            }
            
            // Skip past events
            if(currentTime > event->time + back) continue;
            
            // Break if future events are too far
            if(currentTime < event->time - ahead) break;
        }
        
        return false;
    }
    
    bool IsWithinFixedNewsTime(datetime currentTime) {
        // Convert to struct to get day, hour, minute
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        
        // Skip weekends for fixed times
        if(dt.day_of_week == 0 || dt.day_of_week == 6) {
            return false;
        }
        
        // Check each fixed time range
        for(int i = 0; i < fixedNewsRanges.Total(); i++) {
            TimeRange* range = (TimeRange*)fixedNewsRanges.At(i);
            
            // Skip if day doesn't match (or if range.dayOfWeek is -1, match any workday)
            if(range->dayOfWeek != -1 && range->dayOfWeek != dt.day_of_week) {
                continue;
            }
            
            // Convert to minutes for comparison
            int currentMinutes = dt.hour * 60 + dt.min;
            int startMinutes = range->startHour * 60 + range->startMinute;
            int endMinutes = range->endHour * 60 + range->endMinute;
            
            // Handle time ranges that cross midnight
            if(endMinutes < startMinutes) {
                if(currentMinutes >= startMinutes || currentMinutes <= endMinutes) {
                    return true;
                }
            }
            // Standard time range check
            else if(currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
                return true;
            }
        }
        
        return false;
    }
};

//+------------------------------------------------------------------+
//| Position Manager Class                                           |
//+------------------------------------------------------------------+
class PositionManager {
private:
    CTrade trade;
    CArrayObj positionInfos;
    
public:
    PositionManager() {
        // ===== CẢI TIẾN 4: Sử dụng tham số đầu vào cho deviation =====
        trade.SetDeviationInPoints(Deviation_Points);
        
        // FIXED: Properly configure CArrayObj for memory management
        positionInfos.FreeMode(true);
    }
    
    ~PositionManager() {
        // CArrayObj::FreeMode(true) ensures objects are deleted with Clear()
        positionInfos.Clear();
    }
    
    // ===== CẢI TIẾN 3: Khôi phục trạng thái lệnh từ comment =====
    void RecoverPositions() {
        if(!Use_State_Persistence) return;
        
        // Clear any existing position info
        positionInfos.Clear();
        
        // Loop through all open positions
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            
            // Check if this position belongs to our EA
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            
            // Create new position info
            PositionInfo* info = new PositionInfo;
            info->ticket = ticket;
            info->openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            info->volume = PositionGetDouble(POSITION_VOLUME);
            info->stopLoss = PositionGetDouble(POSITION_SL); // Current SL, may not be initial
            info->tp1_hit = false;
            info->tp2_hit = false;
            info->trail_with_ssl = false;
            
            // Try to decode state from comment
            string comment = PositionGetString(POSITION_COMMENT);
            bool stateRecovered = DecodePositionState(comment, info);
            
            if(stateRecovered) {
                LogMessage(LOG_INFO, StringFormat("Recovered position: Ticket %llu, TP1 hit: %s, TP2 hit: %s, Trail with SSL: %s",
                          ticket, info->tp1_hit ? "Yes" : "No", info->tp2_hit ? "Yes" : "No", 
                          info->trail_with_ssl ? "Yes" : "No"));
                
                // Add to our tracking array
                positionInfos.Add(info);
            } else {
                // IMPROVED: If state couldn't be recovered, don't manage this position
                LogMessage(LOG_WARNING, StringFormat("WARNING: Position %llu found but state could not be recovered. "
                          "This position will not be managed by the EA until restart.", ticket));
                delete info; // Clean up the untracked info
            }
        }
    }
    
    // ===== CẢI TIẾN 3: Mã hóa trạng thái lệnh vào comment =====
    string EncodePositionState(PositionInfo* info) {
        // Format: EA_Scaping|v1.03|TP1:[0/1]|TP2:[0/1]|TSL:[0/1]|ISL:[value]
        return StringFormat("EA_Scaping|v1.03|TP1:%d|TP2:%d|TSL:%d|ISL:%.5f",
                          info->tp1_hit ? 1 : 0,
                          info->tp2_hit ? 1 : 0,
                          info->trail_with_ssl ? 1 : 0,
                          info->stopLoss);
    }
    
    // ===== CẢI TIẾN 3: Giải mã trạng thái lệnh từ comment =====
    bool DecodePositionState(string comment, PositionInfo* info) {
        // Check if comment is from our EA (version 1.02 or 1.03)
        if(StringFind(comment, "EA_Scaping|v1.0") < 0)
            return false;
            
        // Extract TP1 state
        int tp1_pos = StringFind(comment, "TP1:");
        if(tp1_pos >= 0) {
            info->tp1_hit = (StringSubstr(comment, tp1_pos + 4, 1) == "1");
        } else {
            // Required field missing
            return false;
        }
        
        // Extract TP2 state
        int tp2_pos = StringFind(comment, "TP2:");
        if(tp2_pos >= 0) {
            info->tp2_hit = (StringSubstr(comment, tp2_pos + 4, 1) == "1");
        } else {
            // Required field missing
            return false;
        }
        
        // Extract trailing stop state
        int tsl_pos = StringFind(comment, "TSL:");
        if(tsl_pos >= 0) {
            info->trail_with_ssl = (StringSubstr(comment, tsl_pos + 4, 1) == "1");
        } else {
            // Required field missing
            return false;
        }
        
        // Extract initial stop loss
        int isl_pos = StringFind(comment, "ISL:");
        if(isl_pos >= 0) {
            string isl_str = StringSubstr(comment, isl_pos + 4);
            int end_pos = StringFind(isl_str, "|");
            if(end_pos < 0) end_pos = StringLen(isl_str);
            info->stopLoss = StringToDouble(StringSubstr(isl_str, 0, end_pos));
        } else {
            // Required field missing
            return false;
        }
        
        return true;
    }
    
    bool OpenBuyPosition(double lotSize, double sl, double tp = 0) {
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        
        // ===== CẢI TIẾN 5: Cải thiện xử lý lỗi =====
        if(!trade.Buy(lotSize, Symbol(), ask, sl, tp, "EA Scaping - Initializing")) {
            int errorCode = trade.ResultRetcode();
            LogMessage(LOG_ERROR, StringFormat("Error opening Buy position: %s", GetTradeErrorDescription(errorCode)));
            
            // Handle specific error cases
            if(errorCode == 10004 || errorCode == 10006 || errorCode == 10021) {  // Requote, rejected, or prices changed
                // Try again with larger deviation
                trade.SetDeviationInPoints(Retry_Deviation_Points);
                if(!trade.Buy(lotSize, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_ASK), sl, tp, "EA Scaping - Initializing")) {
                    LogMessage(LOG_ERROR, StringFormat("Second attempt failed: %s", GetTradeErrorDescription(trade.ResultRetcode())));
                    trade.SetDeviationInPoints(Deviation_Points);  // Reset deviation
                    return false;
                }
                trade.SetDeviationInPoints(Deviation_Points);  // Reset deviation
            } else {
                return false;
            }
        }
        
        // Get the position details
        ulong ticket = trade.ResultOrder();
        double openPrice = trade.ResultPrice();
        
        // Create position info
        PositionInfo* info = new PositionInfo;
        info->ticket = ticket;
        info->openPrice = openPrice;
        info->stopLoss = sl;
        info->volume = lotSize;
        info->tp1_hit = false;
        info->tp2_hit = false;
        info->trail_with_ssl = false;
        
        // Add to our tracking array
        positionInfos.Add(info);
        
        // ===== CẢI TIẾN 3: Thêm comment chứa trạng thái lệnh =====
        if(Use_State_Persistence) {
            string posState = EncodePositionState(info);
            ModifyPositionWithRetry(ticket, sl, tp, posState);
        }
        
        LogMessage(LOG_INFO, StringFormat("Buy position opened: Ticket %llu, Lot %.2f, Entry %.5f, SL %.5f", 
                  ticket, lotSize, openPrice, sl));
              
        return true;
    }
    
    bool OpenSellPosition(double lotSize, double sl, double tp = 0) {
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        
        // ===== CẢI TIẾN 5: Cải thiện xử lý lỗi =====
        if(!trade.Sell(lotSize, Symbol(), bid, sl, tp, "EA Scaping - Initializing")) {
            int errorCode = trade.ResultRetcode();
            LogMessage(LOG_ERROR, StringFormat("Error opening Sell position: %s", GetTradeErrorDescription(errorCode)));
            
            // Handle specific error cases
            if(errorCode == 10004 || errorCode == 10006 || errorCode == 10021) {  // Requote, rejected, or prices changed
                // Try again with larger deviation
                trade.SetDeviationInPoints(Retry_Deviation_Points);
                if(!trade.Sell(lotSize, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), sl, tp, "EA Scaping - Initializing")) {
                    LogMessage(LOG_ERROR, StringFormat("Second attempt failed: %s", GetTradeErrorDescription(trade.ResultRetcode())));
                    trade.SetDeviationInPoints(Deviation_Points);  // Reset deviation
                    return false;
                }
                trade.SetDeviationInPoints(Deviation_Points);  // Reset deviation
            } else {
                return false;
            }
        }
        
        // Get the position details
        ulong ticket = trade.ResultOrder();
        double openPrice = trade.ResultPrice();
        
        // Create position info
        PositionInfo* info = new PositionInfo;
        info->ticket = ticket;
        info->openPrice = openPrice;
        info->stopLoss = sl;
        info->volume = lotSize;
        info->tp1_hit = false;
        info->tp2_hit = false;
        info->trail_with_ssl = false;
        
        // Add to our tracking array
        positionInfos.Add(info);
        
        // ===== CẢI TIẾN 3: Thêm comment chứa trạng thái lệnh =====
        if(Use_State_Persistence) {
            string posState = EncodePositionState(info);
            ModifyPositionWithRetry(ticket, sl, tp, posState);
        }
        
        LogMessage(LOG_INFO, StringFormat("Sell position opened: Ticket %llu, Lot %.2f, Entry %.5f, SL %.5f", 
                  ticket, lotSize, openPrice, sl));
              
        return true;
    }
    
    // ===== CẢI TIẾN 5: Phương thức sửa lệnh có xử lý thử lại =====
    bool ModifyPositionWithRetry(ulong ticket, double sl, double tp = 0, string comment = "") {
        bool useNewComment = (comment != "");
        
        // Get current position comment if we're not changing it
        if(!useNewComment && Use_State_Persistence) {
            if(PositionSelectByTicket(ticket)) {
                comment = PositionGetString(POSITION_COMMENT);
                useNewComment = true;
            }
        }
        
        // Try to modify position
        if(useNewComment) {
            // Use OrderModify to update comment
            if(!OrderSelect(ticket) || OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_POSITION) {
                LogMessage(LOG_ERROR, StringFormat("Cannot select position order for ticket: %llu", ticket));
                return false;
            }
            
            if(!trade.OrderModify(ticket, 0, sl, tp, ORDER_TIME_GTC, 0, comment)) {
                int errorCode = trade.ResultRetcode();
                LogMessage(LOG_ERROR, StringFormat("Error modifying position %llu: %s", ticket, GetTradeErrorDescription(errorCode)));
                
                // Handle specific errors
                if(errorCode == 10004 || errorCode == 10006 || errorCode == 10021) {  // Requote, rejected, or prices changed
                    trade.SetDeviationInPoints(Retry_Deviation_Points);
                    if(!trade.OrderModify(ticket, 0, sl, tp, ORDER_TIME_GTC, 0, comment)) {
                        LogMessage(LOG_ERROR, StringFormat("Second modify attempt failed: %s", GetTradeErrorDescription(trade.ResultRetcode())));
                        trade.SetDeviationInPoints(Deviation_Points);
                        return false;
                    }
                    trade.SetDeviationInPoints(Deviation_Points);
                    return true;
                }
                return false;
            }
        } else {
            // Standard position modify (no comment change)
            if(!trade.PositionModify(ticket, sl, tp)) {
                int errorCode = trade.ResultRetcode();
                LogMessage(LOG_ERROR, StringFormat("Error modifying position %llu: %s", ticket, GetTradeErrorDescription(errorCode)));
                
                // Handle specific errors
                if(errorCode == 10004 || errorCode == 10006 || errorCode == 10021) {  // Requote, rejected, or prices changed
                    trade.SetDeviationInPoints(Retry_Deviation_Points);
                    if(!trade.PositionModify(ticket, sl, tp)) {
                        LogMessage(LOG_ERROR, StringFormat("Second modify attempt failed: %s", GetTradeErrorDescription(trade.ResultRetcode())));
                        trade.SetDeviationInPoints(Deviation_Points);
                        return false;
                    }
                    trade.SetDeviationInPoints(Deviation_Points);
                    return true;
                }
                return false;
            }
        }
        
        return true;
    }
    
    void ManagePositions(IndicatorCache* cache) {
        // Loop through positions in reverse order as we may close some
        for(int i = positionInfos.Total() - 1; i >= 0; i--) {
            PositionInfo* info = (PositionInfo*)positionInfos.At(i);
            
            // Check if position still exists
            if(!PositionSelectByTicket(info->ticket)) {
                // Position was closed externally, remove from our array
                positionInfos.Delete(i);
                continue;
            }
            
            // Get current position details
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double stopLoss = PositionGetDouble(POSITION_SL);
            double positionVolume = PositionGetDouble(POSITION_VOLUME);
            
            // Calculate the initial risk (distance to stop loss)
            double initialRisk = MathAbs(entryPrice - info->stopLoss);
            
            // Check for exit signals
            if(CheckExitSignal(posType, cache)) {
                if(ClosePosition(info->ticket)) {
                    LogMessage(LOG_INFO, StringFormat("Position %llu closed due to exit signal", info->ticket));
                    positionInfos.Delete(i);
                }
                continue;
            }
            
            // Check TP1 (1.5R)
            if(!info->tp1_hit && MathAbs(currentPrice - entryPrice) >= TP1_R_Multiplier * initialRisk) {
                // Calculate volume to close (30% of original position)
                // FIXED: Use original volume from position info and the input parameter
                double volumeToClose = NormalizeDouble(info->volume * TP1_Position_Size / 100.0, 2);
                
                // Make sure we don't close more than we have
                volumeToClose = MathMin(volumeToClose, positionVolume);
                
                // Close partial position
                if(trade.PositionClosePartial(info->ticket, volumeToClose)) {
                    LogMessage(LOG_INFO, StringFormat("TP1 hit for position %llu, closed %.2f lots", info->ticket, volumeToClose));
                    
                    // Move stop loss to break even
                    info->tp1_hit = true;
                    
                    // ===== CẢI TIẾN 3: Cập nhật comment sau khi TP1 hit =====
                    if(Use_State_Persistence) {
                        string updatedState = EncodePositionState(info);
                        ModifyPositionWithRetry(info->ticket, entryPrice, 0, updatedState);
                    } else {
                        // Move stop loss to break even
                        ModifyPositionWithRetry(info->ticket, entryPrice);
                    }
                    
                    LogMessage(LOG_INFO, StringFormat("Stop loss moved to break even for position %llu", info->ticket));
                }
            }
            
            // Check TP2 (2.5R)
            if(info->tp1_hit && !info->tp2_hit && MathAbs(currentPrice - entryPrice) >= TP2_R_Multiplier * initialRisk) {
                // FIXED: Calculate volume to close (30% of original position)
                double volumeToClose = NormalizeDouble(info->volume * TP2_Position_Size / 100.0, 2);
                
                // Make sure we don't close more than we have
                volumeToClose = MathMin(volumeToClose, positionVolume);
                
                // Close partial position
                if(trade.PositionClosePartial(info->ticket, volumeToClose)) {
                    LogMessage(LOG_INFO, StringFormat("TP2 hit for position %llu, closed %.2f lots", info->ticket, volumeToClose));
                    
                    // Switch to SSL trailing stop
                    info->trail_with_ssl = true;
                    info->tp2_hit = true;
                    
                    // ===== CẢI TIẾN 3: Cập nhật comment sau khi TP2 hit =====
                    if(Use_State_Persistence) {
                        string updatedState = EncodePositionState(info);
                        ModifyPositionWithRetry(info->ticket, stopLoss, 0, updatedState);
                    }
                }
            }
            
            // Handle trailing stop
            if(info->tp1_hit) {
                if(info->trail_with_ssl) {
                    // Use SSL line as trailing stop
                    double sslValue = GetSSLValueOpposite(posType, cache);
                    
                    // Update stop loss if SSL provides better protection
                    if((posType == POSITION_TYPE_BUY && sslValue > stopLoss) ||
                       (posType == POSITION_TYPE_SELL && sslValue < stopLoss)) {
                        // ===== CẢI TIẾN 5: Sử dụng phương thức sửa lệnh cải tiến =====
                        if(ModifyPositionWithRetry(info->ticket, sslValue)) {
                            LogMessage(LOG_INFO, StringFormat("Updated trailing stop to SSL value for position %llu", info->ticket));
                        }
                    }
                }
            }
        }
    }
    
    bool ClosePosition(ulong ticket) {
        // ===== CẢI TIẾN 5: Cải thiện xử lý lỗi =====
        if(trade.PositionClose(ticket)) {
            LogMessage(LOG_INFO, StringFormat("Position %llu closed", ticket));
            return true;
        }
        
        int errorCode = trade.ResultRetcode();
        LogMessage(LOG_ERROR, StringFormat("Error closing position %llu: %s", ticket, GetTradeErrorDescription(errorCode)));
        
        // Handle specific errors
        if(errorCode == 10004 || errorCode == 10006 || errorCode == 10021) {  // Requote, rejected, or prices changed
            // Try again with larger deviation
            trade.SetDeviationInPoints(Retry_Deviation_Points);
            if(trade.PositionClose(ticket)) {
                LogMessage(LOG_INFO, StringFormat("Position %llu closed on second attempt", ticket));
                trade.SetDeviationInPoints(Deviation_Points);  // Reset deviation
                return true;
            }
            trade.SetDeviationInPoints(Deviation_Points);  // Reset deviation
        }
        
        return false;
    }
    
private:
    double GetSSLValueOpposite(ENUM_POSITION_TYPE posType, IndicatorCache* cache) {
        // Get SSL values from cache using enum indices for clarity
        double ssl_upper = cache->GetM15Value(M15_SSL_UPPER_IDX);
        double ssl_lower = cache->GetM15Value(M15_SSL_LOWER_IDX);
        
        // Return the opposite SSL line based on position type
        if(posType == POSITION_TYPE_BUY) {
            return ssl_lower; // Lower line for Buy positions
        }
        else {
            return ssl_upper; // Upper line for Sell positions
        }
    }
    
    bool CheckExitSignal(ENUM_POSITION_TYPE posType, IndicatorCache* cache) {
        // Get indicator values using enum indices for clarity
        double ssl_upper = cache->GetM15Value(M15_SSL_UPPER_IDX);
        double ssl_lower = cache->GetM15Value(M15_SSL_LOWER_IDX);
        double qqe_value = cache->GetM15Value(M15_QQE_VALUE_IDX);
        double qqe_color = cache->GetM15Value(M15_QQE_COLOR_IDX);
        double ema200 = cache->GetM15Value(M15_EMA200_IDX);
        double close = iClose(Symbol(), PERIOD_M15, 1);
        
        // Check for SSL reversal
        bool sslReversal = false;
        if(posType == POSITION_TYPE_BUY && ssl_upper < ssl_lower) {
            sslReversal = true;
        }
        else if(posType == POSITION_TYPE_SELL && ssl_upper > ssl_lower) {
            sslReversal = true;
        }
        
        // Check for QQE reversal - UPDATED: using configured color values
        bool qqeReversal = false;
        if(posType == POSITION_TYPE_BUY && (qqe_value < 0 || qqe_color == QQE_Bearish_Color_Value)) {
            qqeReversal = true;
        }
        else if(posType == POSITION_TYPE_SELL && (qqe_value > 0 || qqe_color == QQE_Bullish_Color_Value)) {
            qqeReversal = true;
        }
        
        // Check for EMA200 break
        bool emaBreak = false;
        if(posType == POSITION_TYPE_BUY && close < ema200) {
            emaBreak = true;
        }
        else if(posType == POSITION_TYPE_SELL && close > ema200) {
            emaBreak = true;
        }
        
        // Exit if any of the conditions are met
        return sslReversal || qqeReversal || emaBreak;
    }
};

// ===== THÊM MỚI: Theo dõi hiệu suất EA =====
class PerformanceTracker {
private:
    int totalTrades;
    int winTrades;
    int lossTrades;
    double totalProfit;
    double totalLoss;
    datetime trackingStarted;
    
public:
    PerformanceTracker() {
        Reset();
    }
    
    void Reset() {
        totalTrades = 0;
        winTrades = 0;
        lossTrades = 0;
        totalProfit = 0;
        totalLoss = 0;
        trackingStarted = TimeCurrent();
    }
    
    void RecordTrade(bool isWin, double profitAmount) {
        totalTrades++;
        if(isWin) {
            winTrades++;
            totalProfit += profitAmount;
            LogMessage(LOG_INFO, StringFormat("Performance: Win trade recorded, profit: %.2f", profitAmount));
        } else {
            lossTrades++;
            totalLoss += MathAbs(profitAmount);
            LogMessage(LOG_INFO, StringFormat("Performance: Loss trade recorded, loss: %.2f", profitAmount));
        }
    }
    
    string GetSummary() {
        double winRate = totalTrades > 0 ? (double)winTrades/totalTrades*100 : 0;
        double profitFactor = totalLoss > 0 ? totalProfit/totalLoss : (totalProfit > 0 ? 999 : 0);
        int days = (int)((TimeCurrent() - trackingStarted) / 86400);
        
        return StringFormat("Performance Summary (last %d days):\n"
                           "Trades: %d\n"
                           "Win/Loss: %d/%d (%.2f%%)\n"
                           "Net profit: %.2f\n"
                           "Profit Factor: %.2f",
                           days,
                           totalTrades,
                           winTrades, lossTrades, winRate,
                           totalProfit - totalLoss,
                           profitFactor);
    }
};

//+------------------------------------------------------------------+
//| Main EA Class                                                    |
//+------------------------------------------------------------------+
class EAScaping {
private:
    H4TrendAnalyzer* h4Analyzer;    // H4 trend analyzer
    M15EntryFinder* m15Finder;      // M15 entry finder
    PositionManager* posManager;    // Position manager
    RiskManager* riskManager;       // Risk manager
    NewsFilter* newsFilter;         // News filter
    IndicatorCache* indicCache;     // Indicator cache
    PerformanceTracker* perfTracker; // Performance tracker
    
    bool isInitialized;             // Initialization flag
    bool allowTrading;              // Trading allowed flag
    
public:
    EAScaping() {
        isInitialized = false;
        allowTrading = Enable_Trading;
        
        // Initialize pointers to NULL
        h4Analyzer = NULL;
        m15Finder = NULL;
        posManager = NULL;
        riskManager = NULL;
        newsFilter = NULL;
        indicCache = NULL;
        perfTracker = NULL;
    }
    
    ~EAScaping() {
        DeInit();
    }
    
    bool Init() {
        // Initialize indicator cache first
        indicCache = new IndicatorCache();
        if(!indicCache->Init()) {
            LogMessage(LOG_ERROR, "Error initializing indicator cache");
            return false;
        }
        
        // Initialize components
        h4Analyzer = new H4TrendAnalyzer(indicCache);
        m15Finder = new M15EntryFinder(indicCache);
        posManager = new PositionManager();
        riskManager = new RiskManager(Risk_Percent, Max_Daily_Risk, Max_Consecutive_Losses);
        newsFilter = new NewsFilter(Use_Calendar_API, Use_Fixed_Hours, 
                                  News_Importance, GMT_Offset, DST_Offset);
        perfTracker = new PerformanceTracker();
        
        // Set up Observer pattern
        h4Analyzer->AddObserver(m15Finder);
        
        // ===== CẢI TIẾN 3: Khôi phục trạng thái các lệnh đang mở =====
        posManager->RecoverPositions();
        
        isInitialized = true;
        LogMessage(LOG_INFO, "EA Scaping initialized successfully");
        return true;
    }
    
    void ProcessTick() {
        if(!isInitialized) return;
        
        // IMPROVED: Centralized indicator cache update for all components
        indicCache->UpdateH4Data();
        indicCache->UpdateM15Data();
        
        // Update risk management stats
        riskManager->Reset();
        
        // Update H4 analyzer (passes false since we already updated cache)
        h4Analyzer->Update(false);
        
        // Update M15 entry finder (passes false since we already updated cache)
        m15Finder->Update(false);
        
        // Check if trading is allowed
        allowTrading = IsAllowedToTrade();
        
        // Manage open positions
        posManager->ManagePositions(indicCache);
        
        // Check for new entry signals if we can trade
        if(allowTrading) {
            CheckForNewSignals();
        }
    }
    
    // THÊM MỚI: Xử lý lệnh đã đóng
    void ProcessClosedPosition(ulong ticket, bool isWin, double profitAmount) {
        // Calculate profit as percentage of account balance
        // Lưu ý: Tính toán dựa trên balance hiện tại, không phải balance tại thời điểm mở lệnh
        // Đủ chính xác cho mục đích theo dõi giới hạn lỗ hàng ngày
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double profitPercent = (profitAmount / balance) * 100.0;
        
        LogMessage(LOG_INFO, StringFormat("Position %llu closed: %s, Profit: %.2f (%.2f%%)", 
                  ticket, isWin ? "Win" : "Loss", profitAmount, profitPercent));
        
        // Update performance statistics
        if(perfTracker != NULL) {
            perfTracker->RecordTrade(isWin, profitAmount);
        }
        
        // Update risk statistics
        if(riskManager != NULL) {
            riskManager->UpdateStats(isWin, profitPercent);
        }
        
        // Log performance summary periodically based on configurable frequency
        static int tradeCount = 0;
        tradeCount++;
        
        if(Log_Summary_Frequency > 0 && tradeCount % Log_Summary_Frequency == 0 && perfTracker != NULL) {
            LogMessage(LOG_INFO, "Performance Summary:\n" + perfTracker->GetSummary());
        }
    }
    
    void DeInit() {
        // Clean up all components
        if(h4Analyzer != NULL) {
            delete h4Analyzer;
            h4Analyzer = NULL;
        }
        
        if(m15Finder != NULL) {
            delete m15Finder;
            m15Finder = NULL;
        }
        
        if(posManager != NULL) {
            delete posManager;
            posManager = NULL;
        }
        
        if(riskManager != NULL) {
            delete riskManager;
            riskManager = NULL;
        }
        
        if(newsFilter != NULL) {
            delete newsFilter;
            newsFilter = NULL;
        }
        
        if(perfTracker != NULL) {
            // Print final performance summary
            LogMessage(LOG_INFO, perfTracker->GetSummary());
            delete perfTracker;
            perfTracker = NULL;
        }
        
        // Clean up indicator cache last
        if(indicCache != NULL) {
            delete indicCache;
            indicCache = NULL;
        }
        
        isInitialized = false;
        LogMessage(LOG_INFO, "EA Scaping deinitialized successfully");
    }
    
private:
    bool IsAllowedToTrade() {
        // Check if trading is enabled
        if(!Enable_Trading) {
            return false;
        }
        
        // Check if market is open
        if(!IsMarketOpen()) {
            return false;
        }
        
        // Check for news events
        if(Use_News_Filter && newsFilter->IsNewsTime()) {
            LogMessage(LOG_INFO, "Trading paused due to news");
            return false;
        }
        
        // Check risk management rules
        if(!riskManager->CanOpenPosition()) {
            return false;
        }
        
        return true;
    }
    
    void CheckForNewSignals() {
        // Only check for new signals if we are below the max positions limit
        if(PositionsTotal() < Max_Positions) { // FIXED: Allow opening up to Max_Positions
            // Check for buy signal
            if(m15Finder->CheckBuySignal()) {
                // Calculate SL based on ATR
                double atr = indicCache->GetM15Value(M15_ATR_IDX);
                double slDistance = atr * SL_ATR_Multiplier_M15;
                double entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
                double stopLoss = entryPrice - slDistance;
                
                // Calculate lot size
                double lotSize = riskManager->CalculateLotSize(slDistance);
                
                // Open buy position
                posManager->OpenBuyPosition(lotSize, stopLoss);
            }
            // Check for sell signal
            else if(m15Finder->CheckSellSignal()) {
                // Calculate SL based on ATR
                double atr = indicCache->GetM15Value(M15_ATR_IDX);
                double slDistance = atr * SL_ATR_Multiplier_M15;
                double entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
                double stopLoss = entryPrice + slDistance;
                
                // Calculate lot size
                double lotSize = riskManager->CalculateLotSize(slDistance);
                
                // Open sell position
                posManager->OpenSellPosition(lotSize, stopLoss);
            }
        }
    }
    
    bool IsMarketOpen() {
        // Check if market is closed (weekend or holidays)
        datetime time = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(time, dt);
        
        // Check weekend
        if(dt.day_of_week == 0 || dt.day_of_week == 6) {
            return false;
        }
        
        // Check if symbol is available for trading
        if(!SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE)) {
            return false;
        }
        
        return true;
    }
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Initialize indicator handles first
    // SSL Hybrid indicator - Assuming you have this custom indicator
    h4_ssl_handle = iCustom(Symbol(), PERIOD_H4, "SSL Hybrid", SSL_Period_H4);
    m15_ssl_handle = iCustom(Symbol(), PERIOD_M15, "SSL Hybrid", SSL_Period_M15);
    
    // QQE MOD indicator - Assuming you have this custom indicator
    m15_qqe_handle = iCustom(Symbol(), PERIOD_M15, "QQE MOD", QQE_Period, QQE_SF, QQE_Fast, QQE_Slow);
    
    // ===== CẢI TIẾN 2: Kiểm tra số lượng buffer của các chỉ báo tùy chỉnh =====
    // Verify SSL buffer count
    if(h4_ssl_handle != INVALID_HANDLE) {
        int ssl_buffers = iBufCount(h4_ssl_handle);
        if(ssl_buffers < 2) {
            LogMessage(LOG_ERROR, StringFormat("Error: SSL Hybrid indicator requires at least 2 buffers, found: %d", ssl_buffers));
            return INIT_FAILED;
        }
    }
    
    // Verify QQE buffer count
    if(m15_qqe_handle != INVALID_HANDLE) {
        int qqe_buffers = iBufCount(m15_qqe_handle);
        if(qqe_buffers <= QQE_Color_Buffer_Index) {
            LogMessage(LOG_ERROR, StringFormat("Error: QQE MOD indicator requires at least %d buffers, found: %d", QQE_Color_Buffer_Index + 1, qqe_buffers));
            return INIT_FAILED;
        }
    }
    
    // Standard indicators
    h4_adx_handle = iADX(Symbol(), PERIOD_H4, ADX_Period);
    m15_rsi_handle = iRSI(Symbol(), PERIOD_M15, RSI_Period, PRICE_CLOSE);
    h4_ema_handle = iMA(Symbol(), PERIOD_H4, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m15_ema_handle = iMA(Symbol(), PERIOD_M15, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m15_atr_handle = iATR(Symbol(), PERIOD_M15, ATR_Period);
    m15_bbw_handle = iBands(Symbol(), PERIOD_M15, BBW_Period, 0, BBW_Deviation, PRICE_CLOSE);
    
    // Check if all handles are valid
    if(h4_ssl_handle == INVALID_HANDLE || 
       m15_ssl_handle == INVALID_HANDLE ||
       m15_qqe_handle == INVALID_HANDLE ||
       h4_adx_handle == INVALID_HANDLE ||
       m15_rsi_handle == INVALID_HANDLE ||
       h4_ema_handle == INVALID_HANDLE ||
       m15_ema_handle == INVALID_HANDLE ||
       m15_atr_handle == INVALID_HANDLE ||
       m15_bbw_handle == INVALID_HANDLE) {
        LogMessage(LOG_ERROR, StringFormat("Error initializing indicators: %d", GetLastError()));
        return INIT_FAILED;
    }
    
    // Create and initialize the EA
    ea = new EAScaping();
    if(!ea->Init()) {
        LogMessage(LOG_ERROR, "EA initialization failed");
        return INIT_FAILED;
    }
    
    // Set up trading parameters - FIXED: Use input MagicNumber
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(Symbol());
    
    LogMessage(LOG_INFO, "EA Scaping initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Release indicator handles
    if(h4_ssl_handle != INVALID_HANDLE) IndicatorRelease(h4_ssl_handle);
    if(m15_ssl_handle != INVALID_HANDLE) IndicatorRelease(m15_ssl_handle);
    if(m15_qqe_handle != INVALID_HANDLE) IndicatorRelease(m15_qqe_handle);
    if(h4_adx_handle != INVALID_HANDLE) IndicatorRelease(h4_adx_handle);
    if(m15_rsi_handle != INVALID_HANDLE) IndicatorRelease(m15_rsi_handle);
    if(h4_ema_handle != INVALID_HANDLE) IndicatorRelease(h4_ema_handle);
    if(m15_ema_handle != INVALID_HANDLE) IndicatorRelease(m15_ema_handle);
    if(m15_atr_handle != INVALID_HANDLE) IndicatorRelease(m15_atr_handle);
    if(m15_bbw_handle != INVALID_HANDLE) IndicatorRelease(m15_bbw_handle);
    
    // Clean up the EA
    if(ea != NULL) {
        delete ea;
        ea = NULL;
    }
    
    LogMessage(LOG_INFO, StringFormat("EA Scaping deinitialized, reason: %d", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Process tick in the EA
    if(ea != NULL) {
        ea->ProcessTick();
    }
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler (NEW in v1.03)                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    // Kiểm tra xem EA đã được khởi tạo chưa
    if(ea == NULL) {
        // LogMessage(LOG_DEBUG, "OnTradeTransaction called before EA initialization complete.");
        return; // Thoát sớm nếu EA chưa sẵn sàng
    }
    
    // Only interested in DEAL_ADD transactions (deals being added to history)
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
    
    // Get deal information
    ulong dealTicket = trans.deal;
    HistorySelect(0, TimeCurrent()); // Select all history for today
    
    if(!HistoryDealSelect(dealTicket)) return;
    
    // Check if this deal is for our EA
    long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
    string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
    
    if(dealMagic != MagicNumber || dealSymbol != Symbol()) return;
    
    // Check if this is a position closing deal
    ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    
    if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY) {
        // Position closed, get the profit
        double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        
        // Get position ticket this deal closed
        ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
        
        // Let EA process this closed position - sử dụng -> vì ea là con trỏ
        ea->ProcessClosedPosition(posTicket, dealProfit > 0, MathAbs(dealProfit));
    }
}

//+------------------------------------------------------------------+
//| Custom functions to handle SSL and QQE indicators                |
//+------------------------------------------------------------------+
/*
 * NOTE TO USER:
 * 
 * This EA assumes you have the SSL Hybrid and QQE MOD indicators already installed.
 * You may need to adjust the function calls and buffer indices based on 
 * the actual implementation of your custom indicators.
 *
 * For SSL Hybrid, we assume:
 *    Buffer 0 = Upper Line (Green)
 *    Buffer 1 = Lower Line (Red)
 *
 * For QQE MOD, the buffer indices are now configurable:
 *    Buffer 0 = QQE Line (default)
 *    Buffer QQE_Color_Buffer_Index = Color buffer (default: 3)
 *    
 * The color values for QQE are also configurable via:
 *    QQE_Bullish_Color_Value (default: 1)
 *    QQE_Bearish_Color_Value (default: -1)
 *
 * The iBufCount function in OnInit now verifies that these indicators have enough buffers.
 * 
 * IMPORTANT: When running with DST_Offset = 1 during Daylight Saving Time periods,
 * you need to switch it back to 0 when DST ends to maintain correct news filter times.
 * 
 * Position state persistence is enabled by default (Use_State_Persistence = true), which
 * allows the EA to remember position states (TP1/TP2 hit, trailing status) after restarts.
 * 
 * NEW IN v1.03: Performance tracking is now integrated with OnTradeTransaction to
 * automatically record and report trading performance statistics.
 */