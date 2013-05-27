require 'rgen/environment'
require 'rgen/util/file_change_detector'
require 'rgen/fragment/model_fragment'
require 'rtext/instantiator'

module RText

# Loads RText files into a FragmentedModel.
#
# A glob pattern or file provider specifies the files which should be loaded. The load method
# can be called to load and to reload the model. Only changed files will be reloaded. 
#
# Optionally, the loader can use a fragment cache to speed up loading.
#
class DefaultLoader

  # Create a default loader for +language+, loading into +fragmented_model+.
  # It will find files either by evaluating the glob pattern given with +:pattern+ 
  # (see Dir.glob) or by means of a +file_provider+. Options:
  #
  #  :pattern
  #    a glob pattern or an array of glob patterns
  #    alternatively, a +:file_provider+ may be specified
  #
  #  :file_provider
  #    a proc which is called without any arguments and should return the files to load
  #    this is an alternative to providing +:pattern+
  #
  #  :cache
  #    a fragment cache to be used for loading
  #
  #  :dont_reload_with_errors
  #    if set to true, don't reload fragments which have parse errors 
  #    instead keep the existing fragment but attach the new problem list
  #
  def initialize(language, fragmented_model, options={})
    @lang = language
    @model = fragmented_model
    @files_added = []
    @files_changed = []
    @files_removed = []
    @change_detector = RGen::Util::FileChangeDetector.new(
      :file_added => lambda {|f| @files_added << f }, 
      :file_removed => lambda {|f| @files_removed << f},
      :file_changed => lambda {|f| @files_changed << f})
    @cache = options[:cache]
    @fragment_by_file = {}
    pattern = options[:pattern]
    @file_provider = options[:file_provider] || proc { Dir.glob(pattern) }
    @dont_reload_with_errors = options[:dont_reload_with_errors]
  end

  # Loads or reloads model fragments from files using the file patterns or file provider 
  # specified in the constructor. Options:
  #
  #  :before_load
  #    a proc which is called before a file is actually loaded, receives the fragment to load
  #    into and a symbol indicating the kind of loading: :load, :load_cached, :load_update_cache
  #    optionally, the proc may take third argument which is the overall number of files
  #    default: no before load proc
  # 
  #  :after_load
  #    a proc which is called after a file has been loaded, receives the fragment loaded
  #    optionally, the proc may take second argument which is the overall number of files
  #    default: no after load proc
  #
  #  :on_progress
  #    a proc which is called when some progress is made 
  #    receives the current fragment being loaded, the actual work done as an integer and
  #    the overall work to be done as an integer
  #    default: no on progress proc
  #
  def load(options={})
    @before_load_proc = options[:before_load]
    @after_load_proc = options[:after_load]
    files = @file_provider.call 
    @num_files = files.size
    @files_added = []
    @files_changed = []
    @files_removed = []
    @change_detector.check_files(files)
    @progress_monitor = ProgressMonitor.new(options[:on_progress], @files_added + @files_changed)
    @files_added.each {|f| file_added(f)}
    @files_changed.each {|f| file_changed(f)}
    @files_removed.each {|f| file_removed(f)}
    @lang.reference_qualifier.call(@model.unresolved_refs, @model)
    @model.resolve(:fragment_provider => method(:fragment_provider),
      :use_target_type => @lang.per_type_identifier)
  end

  private

  class ProgressMonitor
    def initialize(on_progress_proc, files)
      @on_progress_proc = on_progress_proc || lambda {|frag, work_done, work_overall| }
      # there is a progress call twice for each element (in tokenizer and instantiator)
      @work_overall = num_elements(files)*2
      @work_done = 0
      @work_last_sent = 0
    end

    def before_fragment_load(frag, kind)
      @loading_cached = (kind == :load_cached)
    end

    def after_fragment_load(frag)
      @work_done += frag.elements.size*2 if @loading_cached
      @on_progress_proc.call(frag, @work_done, @work_overall)
      @work_last_sent = @work_done
    end

    def instantiator_progress(frag)
      @work_done += 1
      if @work_done > @work_last_sent + 100
        @on_progress_proc.call(frag, @work_done, @work_overall)
        @work_last_sent = @work_done
      end
    end

    private

    def num_elements(files)
      result = 0
      files.each do |f|
        content = File.open(f, "rb"){|fh| fh.read}
        result += content.scan(/\n\s*\w+\s+/).size
        result += 1 if content =~ /^\s*\w+\s+/
      end
      result
    end
  end

  def file_added(file)
    fragment = RGen::Fragment::ModelFragment.new(file, 
      :identifier_provider => lambda {|e, c| @lang.identifier_provider.call(e, nil, nil, nil)})
    load_fragment_cached(fragment)
    @model.add_fragment(fragment)
    @fragment_by_file[file] = fragment
  end

  def file_removed(file)
    @model.remove_fragment(@fragment_by_file[file])
    @fragment_by_file.delete(file)
  end

  def file_changed(file)
    fragment = RGen::Fragment::ModelFragment.new(file, 
      :identifier_provider => lambda {|e, c| @lang.identifier_provider.call(e, nil, nil, nil)})
    load_fragment_cached(fragment)
    if @dont_reload_with_errors && fragment.data[:problems].size > 0
      # keep old fragment but attach new problems
      old_fragment = @fragment_by_file[file]
      old_fragment.data[:problems] = fragment.data[:problems] 
    else
      file_removed(file)
      @model.add_fragment(fragment)
      @fragment_by_file[file] = fragment
    end
  end

  def fragment_provider(element)
    fr = @lang.fragment_ref(element)
    fr && fr.fragment
  end

  def load_fragment_cached(fragment)
    if @cache
      begin
        result = @cache.load(fragment)
      rescue ArgumentError => e
        # Marshal#load raises an ArgumentError if required classes are not present
        if e.message =~ /undefined class\/module/
          result = :invalid
        else
          raise
        end
      end
      if result == :invalid
        call_before_load_proc(fragment, :load_update_cache)
        load_fragment(fragment)
        @cache.store(fragment)
        call_after_load_proc(fragment)
      else
        call_before_load_proc(fragment, :load_cached)
        call_after_load_proc(fragment)
      end
    else
      call_before_load_proc(fragment, :load)
      load_fragment(fragment)
      call_after_load_proc(fragment)
    end
  end

  def call_before_load_proc(fragment, kind)
    @progress_monitor.before_fragment_load(fragment, kind)
    if @before_load_proc
      if @before_load_proc.arity == 3
        @before_load_proc.call(fragment, kind, @num_files) 
      else
        @before_load_proc.call(fragment, kind) 
      end
    end
  end

  def call_after_load_proc(fragment)
    @progress_monitor.after_fragment_load(fragment)
    if @after_load_proc
      if @after_load_proc.arity == 2
        @after_load_proc.call(fragment, @num_files) 
      else
        @after_load_proc.call(fragment) 
      end
    end
  end

  def load_fragment(fragment)
    env = RGen::Environment.new
    urefs = []
    problems = []
    root_elements = []
    inst = RText::Instantiator.new(@lang)
    begin
      File.open(fragment.location, "rb") do |f|
        inst.instantiate(f.read,
          :env => env,
          :unresolved_refs => urefs,
          :problems => problems,
          :root_elements => root_elements,
          :fragment_ref => fragment.fragment_ref,
          :file_name => fragment.location,
          :on_progress => lambda do 
            @progress_monitor.instantiator_progress(fragment)
          end)
      end
    rescue Errno::ENOENT
      # missing file, treat as empty
    end
    # data might have been created during instantiation (e.g. comment or annotation handler)
    fragment.data ||= {}
    fragment.data[:problems] = problems
    fragment.set_root_elements(root_elements,
      :unresolved_refs => urefs, 
      :elements => env.elements)
    fragment.build_index
    @lang.reference_qualifier.call(urefs, fragment)
    fragment.resolve_local(:use_target_type => @lang.per_type_identifier)
  end

end

end

