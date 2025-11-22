module RailsCharts
  class BaseChart
    CHART_JS_PATTERN = /"RAILS_CHART_JS:((?!RAILS_CHART_JS:).*?):RAILS_CHART_JS_END"/

    using RubyExt

    attr_reader :data, :options, :chart_id, :container_id, :defaults
    attr_reader :width, :height, :style, :klass, :theme, :locale, :renderer
    attr_reader :other_options, :debug
    attr_reader :vertical, :nonce

    def initialize(data, options = {})
      @data          = data
      @options       = options
      @other_options = options.delete(:options).presence || {}
      @defaults      = RailsCharts.defaults[self.class].presence || {}

      @chart_id      = "rails_charts_#{Digest::SHA1.hexdigest([Time.now, rand].join)}"
      @container_id  = options.delete(:id).presence || @chart_id

      @width         = options.delete(:width).presence || RailsCharts.options[:width]
      @height        = options.delete(:height).presence || RailsCharts.options[:height]
      @theme         = options.delete(:theme).presence || RailsCharts.options[:theme]
      @locale        = options.delete(:locale).presence || RailsCharts.options[:locale]
      @renderer      = options.delete(:renderer).presence || RailsCharts.options[:renderer] || "canvas"
      @klass         = options.delete(:class).presence || RailsCharts.options[:class]
      @style         = options.delete(:style).presence || RailsCharts.options[:style]

      @debug         = options.delete(:debug)

      @vertical      = options.delete(:vertical).presence
      @nonce         = options.delete(:nonce)
    end

    def js_code
      style_css = []
      style_css << "width: #{width}" if width
      style_css << "height: #{height}" if height
      style_css << style

      nonce_attr = nonce ? %Q{ nonce="#{ERB::Util.html_escape(nonce)}"} : ""

      %Q{
        <div id="#{container_id}" class="#{klass}" style="#{style_css.compact.join('; ')}">
          <script#{nonce_attr}>
            if (!window.RailsCharts) {
              window.RailsCharts = {}
              window.RailsCharts.charts = {}
            }

            (function() {
              var chartId = '#{chart_id}';
              var containerId = '#{container_id}';

              function init(e) {
                if (document.documentElement.hasAttribute("data-turbolinks-preview")) return;
                if (document.documentElement.hasAttribute("data-turbo-preview")) return;

                var chartDom = document.getElementById(containerId);
                if (!chartDom) return;

                // Avoid reinitializing if chart already exists and is valid
                var existingChart = window.RailsCharts.charts[containerId];
                if (existingChart && !existingChart.isDisposed()) return;

                var lib = ("echarts" in window) ? window.echarts : echarts;
                var chart = lib.init(chartDom, #{theme.to_json}, { "locale": #{locale.to_json}, "renderer": #{renderer.to_json} });
                var option = #{option};
                option && chart.setOption(option);

                window.RailsCharts.charts[containerId] = chart;

                chart.on('rendered', function() {
                  document.dispatchEvent(new CustomEvent('chart:rendered', {
                    detail: { containerId: containerId }
                  }));
                });
              }

              function destroy(e) {
                var chart = window.RailsCharts.charts[containerId];
                if (chart && !chart.isDisposed()) {
                  chart.dispose();
                }
                delete window.RailsCharts.charts[containerId];
              }

              // Cleanup before Turbo/Turbolinks navigation
              document.addEventListener("turbolinks:before-render", destroy);
              document.addEventListener("turbo:before-render", destroy);

              // Initialize on various load events
              window.addEventListener('load', init);
              window.addEventListener('turbo:load', init);
              window.addEventListener('turbolinks:load', init);
              window.addEventListener('turbo:render', init);

              // Turbo Frame support
              window.addEventListener('turbo:frame-render', init);
              window.addEventListener('turbo:frame-load', function frameLoadHandler() {
                window.removeEventListener('turbo:frame-render', init);
              });

              // Initialize immediately if DOM is ready (for Turbo Drive navigation)
              // When Turbo replaces the page, scripts run after turbo:load has fired,
              // so we need to initialize immediately if the document is already loaded
              if (document.readyState === 'complete' || document.readyState === 'interactive') {
                // Use requestAnimationFrame to ensure DOM is fully painted
                requestAnimationFrame(function() {
                  init();
                });
              }
            })();
          </script>
        </div>
      }
    end

    def option
      str = build_options.to_json
      str.gsub!(CHART_JS_PATTERN) { Base64.decode64($1).force_encoding(Encoding::UTF_8) }
      str
    end

    def build_options
      hash = {}

      hash[:series] = Array.wrap(generate_series_options)

      hash = hash.complex_merge(axises)
      hash = hash.complex_merge(defaults)
      hash = hash.complex_merge(other_options)

      hash
    end

    def axises
      if self.vertical
        {
          xAxis: y_axis,
          yAxis: x_axis,
        }
      else
        {
          xAxis: x_axis,
          yAxis: y_axis,
        }
      end
    end

    def x_axis
      []
    end

    def y_axis
      []
    end

  end
end
