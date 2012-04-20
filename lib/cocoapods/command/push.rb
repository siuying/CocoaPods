require 'fileutils'

module Pod
  class Command
    class Push < Command
      def self.banner
        %{Pushing new specifications to a spec-repo:

    $ pod push [REPO]

      Validates `*.podspec' in the current working dir, updates
      the local copy of the repository named REPO, adds specifications
      to REPO, and finally it pushes REPO to its remote.}
      end

      extend Executable
      executable :git

      def initialize(argv)
        @repo = argv.shift_argument
        super unless argv.empty? && @repo
      end

      def run
        validate_podspec_files!
        check_repo_status!
        update_repo
        add_specs_to_repo
        push_repo
      end

      private

      def update_repo
        puts "Updating the `#{@repo}' repo\n".yellow unless config.silent
        # show the output of git even if not verbose
        Dir.chdir(repo_dir) { puts `git pull` }
      end

      def push_repo
        puts "\nPushing the `#{@repo}' repo\n".yellow unless config.silent
        Dir.chdir(repo_dir) { puts `git push` }
      end

      def repo_dir
        dir = config.repos_dir + @repo
        raise Informative, "[!] `#{@repo}' repo not found".red unless dir.exist?
        dir
      end

      def check_repo_status!
        # TODO: add specs for staged and unstaged files (tested manually)
        status = Dir.chdir(repo_dir) { `git status --porcelain` } == ''
        raise Informative, "[!] `#{@repo}' repo not clean".red unless status
      end

      def podspec_files
        files = Pathname.glob("*.podspec")
        raise Informative, "[!] Couldn't find .podspec file in current directory".red if files.empty?
        files
      end

      def validate_podspec_files!
        puts "\nValidating specs\n".yellow unless config.silent
        lint_argv = ["lint"]
        lint_argv << "--silent" if config.silent
        all_valid = Spec.new(ARGV.new(lint_argv)).run
        raise Informative, "[!] All specs must pass validation before push".red unless all_valid
      end

      def add_specs_to_repo

        puts "\nAdding the specs to the #{@repo} repo\n".yellow unless config.silent
        podspec_files.each do |spec_file|
          spec = Pod::Specification.from_file(spec_file)

          output_path = File.join(repo_dir, spec.name, spec.version.to_s)

          if Pathname.new(output_path).exist?
            message = "[Fix] #{spec}"
          elsif Pathname.new(File.join(repo_dir, spec.name)).exist?
            message = "[Update] #{spec}"
          else
            message = "[Add] #{spec}"
          end
          puts " - #{message}" unless config.silent

          FileUtils.mkdir_p(output_path)
          FileUtils.cp(Pathname.new(spec.name+'.podspec'), output_path)
          Dir.chdir(repo_dir) do
            git("add #{spec.name}")
            git("commit -m '#{message}'")
          end
        end
      end
    end
  end
end