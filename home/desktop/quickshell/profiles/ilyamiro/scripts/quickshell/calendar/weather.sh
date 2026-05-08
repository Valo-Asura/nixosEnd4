#!/usr/bin/env bash

# Force standard C locale for number formatting and date parsing (fixes printf and date command issues on varying OS locales)
export LC_ALL=C

# Paths
cache_dir="$HOME/.cache/quickshell/weather"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"
daily_cache_file="${cache_dir}/daily_weather_cache.json"
next_day_cache_file="${cache_dir}/next_day_precache.json"
ENV_FILE="$(dirname "$0")/.env"

# API Settings
# Load environment variables silently
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi

# API Settings from .env
KEY="${OPENWEATHER_KEY:-}"
ID="${OPENWEATHER_CITY_ID:-1258128}"
UNIT="${OPENWEATHER_UNIT:-metric}" # Default to metric if not set
OPENMETEO_LATITUDE="${OPENMETEO_LATITUDE:-30.0869}"
OPENMETEO_LONGITUDE="${OPENMETEO_LONGITUDE:-78.2676}"
OPENMETEO_LOCATION="${OPENMETEO_LOCATION:-Gumaniwala, Uttarakhand}"
OPENMETEO_TIMEZONE="${OPENMETEO_TIMEZONE:-auto}"

# Determine temperature symbol based on unit
case "$UNIT" in
    "imperial") UNIT_SYM="°F" ;;
    "standard") UNIT_SYM="K" ;;
    *) UNIT_SYM="°C" ;;
esac

mkdir -p "${cache_dir}"

get_icon() {
    case $1 in
        "50d"|"50n") icon="󰖑"; quote="Mist" ;;
        "01d") icon=""; quote="Sunny" ;;
        "01n") icon=""; quote="Clear" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") icon=""; quote="Cloudy" ;;
        "09d"|"09n"|"10d"|"10n") icon="󰖗"; quote="Rainy" ;;
        "11d"|"11n") icon=""; quote="Storm" ;;
        "13d"|"13n") icon=""; quote="Snow" ;;
        *) icon=""; quote="Unknown" ;;
    esac
    echo "$icon|$quote"
}

get_hex() {
    case $1 in
        "50d"|"50n") echo "#84afdb" ;;
        "01d") echo "#f9e2af" ;;
        "01n") echo "#cba6f7" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") echo "#bac2de" ;;
        "09d"|"09n"|"10d"|"10n") echo "#74c7ec" ;;
        "11d"|"11n") echo "#f9e2af" ;;
        "13d"|"13n") echo "#cdd6f4" ;;
        *) echo "#cdd6f4" ;;
    esac
}

get_wmo_icon() {
    case $1 in
        0) echo "" ;;
        1|2|3) echo "" ;;
        45|48) echo "󰖑" ;;
        51|53|55|56|57|61|63|65|66|67|80|81|82) echo "󰖗" ;;
        71|73|75|77|85|86) echo "" ;;
        95|96|99) echo "" ;;
        *) echo "" ;;
    esac
}

get_wmo_hex() {
    case $1 in
        0) echo "#f9e2af" ;;
        1|2|3) echo "#bac2de" ;;
        45|48) echo "#84afdb" ;;
        51|53|55|56|57|61|63|65|66|67|80|81|82) echo "#74c7ec" ;;
        71|73|75|77|85|86) echo "#cdd6f4" ;;
        95|96|99) echo "#f9e2af" ;;
        *) echo "#cdd6f4" ;;
    esac
}

get_wmo_desc() {
    case $1 in
        0) echo "Clear Sky" ;;
        1) echo "Mainly Clear" ;;
        2) echo "Partly Cloudy" ;;
        3) echo "Overcast" ;;
        45|48) echo "Fog" ;;
        51|53|55) echo "Drizzle" ;;
        56|57) echo "Freezing Drizzle" ;;
        61|63|65) echo "Rain" ;;
        66|67) echo "Freezing Rain" ;;
        71|73|75) echo "Snow" ;;
        77) echo "Snow Grains" ;;
        80|81|82) echo "Rain Showers" ;;
        85|86) echo "Snow Showers" ;;
        95|96|99) echo "Thunderstorm" ;;
        *) echo "Cloudy" ;;
    esac
}

openmeteo_temperature_unit() {
    case "$UNIT" in
        "imperial") echo "fahrenheit" ;;
        *) echo "celsius" ;;
    esac
}

openmeteo_windspeed_unit() {
    case "$UNIT" in
        "imperial") echo "mph" ;;
        *) echo "ms" ;;
    esac
}

write_dummy_data() {
    final_json="["
    for i in {0..4}; do
        future_date=$(date -d "+$i days")
        f_day=$(date -d "$future_date" "+%a")
        f_full_day=$(date -d "$future_date" "+%A")
        f_date_num=$(date -d "$future_date" "+%d %b")
        
        final_json="${final_json} {
            \"id\": \"${i}\",
            \"day\": \"${f_day}\",
            \"day_full\": \"${f_full_day}\",
            \"date\": \"${f_date_num}\",
            \"max\": \"0.0\",
            \"min\": \"0.0\",
            \"feels_like\": \"0.0\",
            \"wind\": \"0\",
            \"humidity\": \"0\",
            \"pop\": \"0\",
            \"icon\": \"\",
            \"hex\": \"#cdd6f4\",
            \"desc\": \"No API Key\",
            \"hourly\": [{\"time\": \"00:00\", \"temp\": \"0.0\", \"icon\": \"\", \"hex\": \"#cdd6f4\"}]
        },"
    done
    final_json="${final_json%,}]"
    echo "{ \"current_temp\": \"0.0\", \"current_icon\": \"\", \"current_hex\": \"#cdd6f4\", \"forecast\": ${final_json} }" > "${json_file}"
}

get_open_meteo_data() {
    temp_unit="$(openmeteo_temperature_unit)"
    wind_unit="$(openmeteo_windspeed_unit)"
    raw_api=$(curl -fsS --max-time 10 --get "https://api.open-meteo.com/v1/forecast" \
        --data-urlencode "latitude=${OPENMETEO_LATITUDE}" \
        --data-urlencode "longitude=${OPENMETEO_LONGITUDE}" \
        --data-urlencode "current=temperature_2m,weather_code" \
        --data-urlencode "hourly=temperature_2m,weather_code,relative_humidity_2m,apparent_temperature,precipitation_probability,wind_speed_10m" \
        --data-urlencode "daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,wind_speed_10m_max,relative_humidity_2m_mean,precipitation_probability_max" \
        --data-urlencode "timezone=${OPENMETEO_TIMEZONE}" \
        --data-urlencode "forecast_days=5" \
        --data-urlencode "temperature_unit=${temp_unit}" \
        --data-urlencode "windspeed_unit=${wind_unit}" 2>/dev/null || true)

    if [ -z "$raw_api" ] || ! echo "$raw_api" | jq -e '.current and .daily and .hourly' >/dev/null 2>&1; then
        if [ ! -f "$json_file" ]; then
            write_dummy_data
        fi
        return
    fi

    c_temp=$(echo "$raw_api" | jq -r '.current.temperature_2m // 0')
    c_temp=$(printf "%.1f" "$c_temp")
    c_code=$(echo "$raw_api" | jq -r '.current.weather_code // 3')
    c_icon=$(get_wmo_icon "$c_code")
    c_hex=$(get_wmo_hex "$c_code")

    forecast_json="[]"
    counter=0
    while IFS= read -r d; do
        [ -n "$d" ] || continue

        raw_max=$(echo "$raw_api" | jq -r ".daily.temperature_2m_max[$counter] // 0")
        f_max_temp=$(printf "%.1f" "$raw_max")
        raw_min=$(echo "$raw_api" | jq -r ".daily.temperature_2m_min[$counter] // 0")
        f_min_temp=$(printf "%.1f" "$raw_min")
        raw_feels=$(echo "$raw_api" | jq -r ".daily.apparent_temperature_max[$counter] // 0")
        f_feels_like=$(printf "%.1f" "$raw_feels")
        f_pop_pct=$(echo "$raw_api" | jq -r ".daily.precipitation_probability_max[$counter] // 0")
        f_wind=$(echo "$raw_api" | jq -r ".daily.wind_speed_10m_max[$counter] // 0 | round")
        f_hum=$(echo "$raw_api" | jq -r ".daily.relative_humidity_2m_mean[$counter] // 0 | round")
        f_code=$(echo "$raw_api" | jq -r ".daily.weather_code[$counter] // 3")
        f_icon=$(get_wmo_icon "$f_code")
        f_hex=$(get_wmo_hex "$f_code")
        f_desc=$(get_wmo_desc "$f_code")
        f_day=$(date -d "$d" "+%a")
        f_full_day=$(date -d "$d" "+%A")
        f_date_num=$(date -d "$d" "+%d %b")

        hourly_json=$(echo "$raw_api" | jq -c --arg d "$d" '
            def wmo_icon:
                if . == 0 then ""
                elif (. == 1 or . == 2 or . == 3) then ""
                elif (. == 45 or . == 48) then "󰖑"
                elif (. == 51 or . == 53 or . == 55 or . == 56 or . == 57 or . == 61 or . == 63 or . == 65 or . == 66 or . == 67 or . == 80 or . == 81 or . == 82) then "󰖗"
                elif (. == 71 or . == 73 or . == 75 or . == 77 or . == 85 or . == 86) then ""
                elif (. == 95 or . == 96 or . == 99) then ""
                else "" end;
            def wmo_hex:
                if . == 0 then "#f9e2af"
                elif (. == 1 or . == 2 or . == 3) then "#bac2de"
                elif (. == 45 or . == 48) then "#84afdb"
                elif (. == 51 or . == 53 or . == 55 or . == 56 or . == 57 or . == 61 or . == 63 or . == 65 or . == 66 or . == 67 or . == 80 or . == 81 or . == 82) then "#74c7ec"
                elif (. == 71 or . == 73 or . == 75 or . == 77 or . == 85 or . == 86) then "#cdd6f4"
                elif (. == 95 or . == 96 or . == 99) then "#f9e2af"
                else "#cdd6f4" end;
            [range(0; (.hourly.time | length)) as $i
                | select(.hourly.time[$i] | startswith($d))
                | {
                    time: (.hourly.time[$i] | split("T")[1]),
                    temp: (((.hourly.temperature_2m[$i] // 0) * 10 | round / 10) | tostring),
                    icon: ((.hourly.weather_code[$i] // 3) | wmo_icon),
                    hex: ((.hourly.weather_code[$i] // 3) | wmo_hex)
                }
            ][0:8]')

        day_json=$(jq -n \
            --arg id "${counter}" \
            --arg day "${f_day}" \
            --arg day_full "${f_full_day}" \
            --arg date "${f_date_num}" \
            --arg max "${f_max_temp}" \
            --arg min "${f_min_temp}" \
            --arg feels_like "${f_feels_like}" \
            --arg wind "${f_wind}" \
            --arg humidity "${f_hum}" \
            --arg pop "${f_pop_pct}" \
            --arg icon "${f_icon}" \
            --arg hex "${f_hex}" \
            --arg desc "${f_desc}" \
            --argjson hourly "${hourly_json}" \
            '{id: $id, day: $day, day_full: $day_full, date: $date, max: $max, min: $min, feels_like: $feels_like, wind: $wind, humidity: $humidity, pop: $pop, icon: $icon, hex: $hex, desc: $desc, hourly: $hourly}')

        forecast_json=$(jq -n --argjson forecast "$forecast_json" --argjson day "$day_json" '$forecast + [$day]')
        counter=$((counter + 1))
    done <<EOF
$(echo "$raw_api" | jq -r '.daily.time[]?')
EOF

    if [ "$forecast_json" = "[]" ]; then
        write_dummy_data
        return
    fi

    jq -n \
        --arg current_temp "${c_temp}" \
        --arg current_icon "${c_icon}" \
        --arg current_hex "${c_hex}" \
        --argjson forecast "${forecast_json}" \
        '{current_temp: $current_temp, current_icon: $current_icon, current_hex: $current_hex, forecast: $forecast}' > "${json_file}"
}

get_data() {
    # ---------------------------------------------------------
    # NO-KEY FALLBACK (Open-Meteo)
    # ---------------------------------------------------------
    if [[ -z "$KEY" || "$KEY" == "Skipped" || "$KEY" == "OPENWEATHER_KEY" ]]; then
        get_open_meteo_data
        return
    fi

    # ---------------------------------------------------------
    # STANDARD API FETCH LOGIC
    # ---------------------------------------------------------
    forecast_url="http://api.openweathermap.org/data/2.5/forecast?APPID=${KEY}&id=${ID}&units=${UNIT}"
    raw_api=$(curl -sf "$forecast_url")
    
    weather_url="http://api.openweathermap.org/data/2.5/weather?APPID=${KEY}&id=${ID}&units=${UNIT}"
    raw_weather=$(curl -sf "$weather_url")
    
    # Check if curl failed OR if OpenWeather returned an error
    api_cod=$(echo "$raw_api" | jq -r '.cod' 2>/dev/null)
    
    if [ -z "$raw_api" ] || [ -z "$raw_weather" ] || [[ "$api_cod" != "200" ]]; then
        # If curl failed (network glitch, rate limit, API downtime), don't destroy
        # the existing working cache. Just abort the update.
        # If there is NO cache at all, then fall back to no-key weather.
        if [ ! -f "$json_file" ]; then
            get_open_meteo_data
        fi
        return
    fi

    # Parse LIVE current weather conditions to bypass UTC boundary issues
    c_temp=$(echo "$raw_weather" | jq -r '.main.temp')
    c_temp=$(printf "%.1f" "$c_temp")
    c_code=$(echo "$raw_weather" | jq -r '.weather[0].icon')
    c_icon=$(get_icon "$c_code" | cut -d'|' -f1)
    c_hex=$(get_hex "$c_code")

    current_date=$(date +%Y-%m-%d)
    tomorrow_date=$(date -d "tomorrow" +%Y-%m-%d)

    # 1. ROLLOVER CHECK
    if [ -f "$next_day_cache_file" ]; then
        precache_date=$(cat "$next_day_cache_file" | jq -r '.[0].dt_txt' | cut -d' ' -f1)
        if [ "$precache_date" == "$current_date" ]; then
            mv "$next_day_cache_file" "$daily_cache_file"
        fi
    fi

    # 2. PROCESS TODAY
    api_today_items=$(echo "$raw_api" | jq -c ".list[] | select(.dt_txt | startswith(\"$current_date\"))" | jq -s '.')

    if [ -f "$daily_cache_file" ]; then
        cached_date=$(cat "$daily_cache_file" | jq -r '.[0].dt_txt' | cut -d' ' -f1)
        if [ "$cached_date" == "$current_date" ]; then
            merged_today=$(echo "$api_today_items" | jq --slurpfile cache "$daily_cache_file" \
                '($cache[0] + .) | unique_by(.dt) | sort_by(.dt)')
        else
            merged_today="$api_today_items"
        fi
    else
        merged_today="$api_today_items"
    fi

    echo "$merged_today" > "$daily_cache_file"

    # 3. PRE-CACHE TOMORROW
    api_tomorrow_items=$(echo "$raw_api" | jq -c ".list[] | select(.dt_txt | startswith(\"$tomorrow_date\"))" | jq -s '.')
    echo "$api_tomorrow_items" > "$next_day_cache_file"

    # 4. BUILD FINAL JSON
    processed_forecast=$(echo "$raw_api" | jq --argjson today "$merged_today" --arg date "$current_date" \
        '.list = ($today + [.list[] | select(.dt_txt | startswith($date) | not)])')

    if [ ! -z "$processed_forecast" ]; then
        dates=$(echo "$processed_forecast" | jq -r '.list[].dt_txt | split(" ")[0]' | uniq | head -n 5)
        
        final_json="["
        counter=0
        
        for d in $dates; do
            day_data=$(echo "$processed_forecast" | jq "[.list[] | select(.dt_txt | startswith(\"$d\"))]")

            raw_max=$(echo "$day_data" | jq '[.[].main.temp_max] | max')
            f_max_temp=$(printf "%.1f" "$raw_max")

            raw_min=$(echo "$day_data" | jq '[.[].main.temp_min] | min')
            f_min_temp=$(printf "%.1f" "$raw_min")

            raw_feels=$(echo "$day_data" | jq '[.[].main.feels_like] | max')
            f_feels_like=$(printf "%.1f" "$raw_feels")

            f_pop=$(echo "$day_data" | jq '[.[].pop] | max')
            f_pop_pct=$(echo "$f_pop * 100" | bc | cut -d. -f1)
            f_wind=$(echo "$day_data" | jq '[.[].wind.speed] | max | round')
            f_hum=$(echo "$day_data" | jq '[.[].main.humidity] | add / length | round')
            
            f_code=$(echo "$day_data" | jq -r '.[length/2 | floor].weather[0].icon')
            f_desc=$(echo "$day_data" | jq -r '.[length/2 | floor].weather[0].description' | sed -e "s/\b\(.\)/\u\1/g")
            f_icon_data=$(get_icon "$f_code")
            f_icon=$(echo "$f_icon_data" | cut -d'|' -f1)
            f_hex=$(get_hex "$f_code")
            
            f_day=$(date -d "$d" "+%a")
            f_full_day=$(date -d "$d" "+%A")
            f_date_num=$(date -d "$d" "+%d %b")

            hourly_json="["
            count_slots=$(echo "$day_data" | jq '. | length')
            count_slots=$((count_slots-1))
            
            for i in $(seq 0 1 $count_slots); do
                slot_item=$(echo "$day_data" | jq ".[$i]")
                
                raw_s_temp=$(echo "$slot_item" | jq ".main.temp")
                s_temp=$(printf "%.1f" "$raw_s_temp")
                
                s_dt=$(echo "$slot_item" | jq ".dt")
                s_time=$(date -d @$s_dt "+%H:%M")
                s_code=$(echo "$slot_item" | jq -r ".weather[0].icon")
                s_hex=$(get_hex "$s_code")
                s_icon=$(get_icon "$s_code" | cut -d'|' -f1)
                
                hourly_json="${hourly_json} {\"time\": \"${s_time}\", \"temp\": \"${s_temp}\", \"icon\": \"${s_icon}\", \"hex\": \"${s_hex}\"},"
            done
            hourly_json="${hourly_json%,}]"

            final_json="${final_json} {
                \"id\": \"${counter}\",
                \"day\": \"${f_day}\",
                \"day_full\": \"${f_full_day}\",
                \"date\": \"${f_date_num}\",
                \"max\": \"${f_max_temp}\",
                \"min\": \"${f_min_temp}\",
                \"feels_like\": \"${f_feels_like}\",
                \"wind\": \"${f_wind}\",
                \"humidity\": \"${f_hum}\",
                \"pop\": \"${f_pop_pct}\",
                \"icon\": \"${f_icon}\",
                \"hex\": \"${f_hex}\",
                \"desc\": \"${f_desc}\",
                \"hourly\": ${hourly_json}
            },"
            ((counter++))
        done
        final_json="${final_json%,}]"

        echo "{ \"current_temp\": \"${c_temp}\", \"current_icon\": \"${c_icon}\", \"current_hex\": \"${c_hex}\", \"forecast\": ${final_json} }" > "${json_file}"
    fi
}

ensure_data_file() {
    if [ ! -f "$json_file" ]; then
        get_data
    fi
}

# --- MODE HANDLING ---
if [[ "$1" == "--getdata" ]]; then
    get_data

elif [[ "$1" == "--json" ]]; then
    CACHE_LIMIT=900         # 15 minutes for valid working data
    PENDING_RETRY_LIMIT=3600 # 1 hour for invalid/activating keys

    if [ -f "$json_file" ]; then
        file_time=$(stat -c %Y "$json_file")
        current_time=$(date +%s)
        diff=$((current_time - file_time))
        
        if grep -q '"desc": "No API Key"' "$json_file"; then
            if [[ -z "$KEY" || "$KEY" == "Skipped" || "$KEY" == "OPENWEATHER_KEY" ]]; then
                get_data
            elif [ $diff -gt $PENDING_RETRY_LIMIT ]; then
                # Key is pending/invalid. Check once an hour.
                touch "$json_file" # Bump file timestamp slightly to avoid spamming processes
                get_data &
            fi
        else
            # Normal working API key. Check every 15 mins.
            if [ $diff -gt $CACHE_LIMIT ]; then
                touch "$json_file"
                get_data &
            fi
        fi
        cat "$json_file"
    else
        get_data
        cat "$json_file"
    fi

elif [[ "$1" == "--view-listener" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    tail -F "$view_file"

elif [[ "$1" == "--nav" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    current=$(cat "$view_file")
    direction=$2
    max_idx=4
    if [[ "$direction" == "next" ]]; then
        if [ "$current" -lt "$max_idx" ]; then
            new=$((current + 1))
            echo "$new" > "$view_file"
        fi
    elif [[ "$direction" == "prev" ]]; then
        if [ "$current" -gt 0 ]; then
            new=$((current - 1))
            echo "$new" > "$view_file"
        fi
    fi

elif [[ "$1" == "--icon" ]]; then
    ensure_data_file
    cat "$json_file" | jq -r '.forecast[0].icon'

elif [[ "$1" == "--temp" ]]; then 
    ensure_data_file
    t=$(cat "$json_file" | jq -r '.forecast[0].max')
    echo "${t}${UNIT_SYM}"

elif [[ "$1" == "--hex" ]]; then 
    ensure_data_file
    cat "$json_file" | jq -r '.forecast[0].hex'

elif [[ "$1" == "--current-icon" ]]; then
    ensure_data_file
    icon=$(cat "$json_file" | jq -r '.current_icon // empty')
    if [[ -z "$icon" || "$icon" == "null" ]]; then 
        get_data
        icon=$(cat "$json_file" | jq -r '.current_icon')
    fi
    echo "$icon"

elif [[ "$1" == "--current-temp" ]]; then 
    ensure_data_file
    t=$(cat "$json_file" | jq -r '.current_temp // empty')
    if [[ -z "$t" || "$t" == "null" ]]; then 
        get_data
        t=$(cat "$json_file" | jq -r '.current_temp')
    fi
    echo "${t}${UNIT_SYM}"

elif [[ "$1" == "--current-hex" ]]; then
    ensure_data_file
    hex=$(cat "$json_file" | jq -r '.current_hex // empty')
    if [[ -z "$hex" || "$hex" == "null" ]]; then 
        get_data
        hex=$(cat "$json_file" | jq -r '.current_hex')
    fi
    echo "$hex"
fi
