require 'concurrent'

module BackgroundThread

  def background(options = { })
    BackgroundThread::Proxy.new(self, options)
  end

  def bg_run
    Pool.bg_run do
      yield
    end
  end

  class Proxy
    def initialize(receiver, options)
      @receiver = receiver
      @options = options
    end

    def method_missing(method, *args)
      @receiver.method_missing(method, *args) unless @receiver.respond_to?(method)
      reply = Pool.bg_run do
        @receiver.send method, *args
      end
      return reply
    end
  end

  class Pool
    include ClassLogger

    @inner = nil

    def self.get_pool
      if !@inner
        logger.warn "No Background Thread Pool found - will create one now."
        @inner = Concurrent::ThreadPoolExecutor.new(
          min_threads: Settings.background_threads.min,
          max_threads: Settings.background_threads.max,
          max_queue: Settings.background_threads.max_queue
        )
      end
      @inner
    end

    def self.bg_run
      logger.debug "About to add task: #{describe}"
      is_queued = get_pool.post do
        begin
          result = yield
          logger.debug "Background task returned '#{result}'"
        rescue => ex
          error_message = "#{ex.class} #{ex.message}"
          message_lines = [error_message]
          message_lines << ex.backtrace.join("\n ") unless Rails.env == "test"
          logger.error message_lines.join("\n")
        ensure
          # Rails takes care of this for foregrounded request threads, but background jobs must fend for themselves.
          EdoOracle::Connection.clear_active_connections!
        end
      end
      logger.warn "Task was not successfully queued to pool" if !is_queued
      return is_queued
    end


    def self.describe
      pool = get_pool
      return "#{pool.length} threads in pool of max #{pool.max_length}; #{pool.queue_length} tasks on queue"
    end
  end


end
