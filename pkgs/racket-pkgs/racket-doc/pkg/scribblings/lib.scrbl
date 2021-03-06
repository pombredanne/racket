#lang scribble/manual
@(require (for-label (except-in racket/base
                                remove)
                     racket/contract/base
                     pkg
                     pkg/lib
                     (only-in pkg/db current-pkg-catalog-file)
                     net/url
                     syntax/modcollapse
                     setup/getinfo))

@title[#:tag "lib"]{Package Management Functions}

@defmodule[pkg/lib]{The @racketmodname[pkg/lib] library provides
building blocks on which the @racket[pkg] library and @exec{raco pkg}
commands are built. It re-exports the bindings of @racketmodname[pkg/path].}


@deftogether[(
@defform[(with-pkg-lock body ...+)]
@defform[(with-pkg-lock/read-only body ...+)]
)]{

Evaluates the @racket[body]s while holding a lock to prevent
concurrent modification to the package database for the current
@tech{package scope}. Use the @racket[with-pkg-lock/read-only] form
for read-only access.  The lock is reentrant but not upgradable from
read-only.

Use these form to wrap uses of functions from @racketmodname[pkg/lib]
that are documented to require the lock. Other functions from
@racketmodname[pkg/lib] take the lock as needed.}

@deftogether[(
@defparam[current-pkg-scope scope (or/c 'installation 'user
                                        (and/c path? complete-path?))]
@defparam[current-pkg-scope-version s string?]
)]{

Parameters that determine @tech{package scope} for management
operations and, in the case of @racket['user] scope, the relevant
installation name/version.}


@defparam[current-pkg-error err procedure?]{

A parameter whose value is used to report errors that are normally
intended for end uses. The arguments to the procedure are the same
as for @racket[error], except that an initial symbol argument is
omitted.

The default value uses @racket[error] with @racket['pkg] as the first
argument. The @exec{raco pkg} command sets this parameter to use
@racket[raise-user-error] with the sub-command name as its first
argument.}


@defparam[current-pkg-catalogs catalogs (or/c #f (listof url?))]{

A parameter that determines the @tech{package catalogs} that are
consulted to resolve a @tech{package name}. If the parameter's value
is @racket[#f], then the result of @racket[pkg-config-catalogs] is
used.}


@defproc[(pkg-config-catalogs) (listof string?)]{

Returns a list of URL strings for the user's configured @tech{package
catalogs}.}


@defproc[(pkg-directory [name string?]) (or/c path-string? #f)]{

Returns the directory that holds the installation of the installed
(in any scope) package @racket[name], or @racket[#f] if no such package
is installed.}


@defproc[(default-pkg-scope) (or/c 'installation 'user
                                    (and/c path? complete-path?))]{

Returns the user's configured default @tech{package scope}.}


@defproc[(installed-pkg-names [#:scope scope (or/c #f 'installation 'user
                                                   (and/c path? complete-path?))])
         (listof string?)]{

Returns a list of installed package names for the given @tech{package
scope}, where @racket[#f] indicates the user's default @tech{package
scope}.}


@defproc[(installed-pkg-table [#:scope scope (or/c #f 'installation 'user
                                                   (and/c path? complete-path?))])
         (hash/c string? pkg-info?)]{

Returns a hash table of installed packages for the given @tech{package
scope}, where @racket[#f] indicates the user's default @tech{package
scope}.}


@deftogether[(
@defproc[(pkg-desc? [v any/c]) boolean?]
@defproc[(pkg-desc [source string?]
                   [type (or/c #f 'file 'dir 'link 'static-link 
                               'file-url 'dir-url 'github 'name)]
                   [name (or/c string? #f)]
                   [checksum (or/c string? #f)]
                   [auto? boolean?])
         pkg-desc?]
)]{

A @racket[pkg-desc] value describes a package source plus details of its
intended interpretation, where the @racket[auto?] field indicates that
the package is should be treated as installed automatically for a
dependency.}


@defproc[(pkg-stage [desc pkg-desc?]
                    [#:checksum checksum (or/c #f string?) #f]
                    [#:in-place? in-place? boolean? #f]
                    [#:namespace namespace namespace? (make-base-namespace)]
                    [#:strip strip (or/c #f 'source 'binary) #f])
         (values string? path? (or/c #f string?) boolean? (listof module-path?))]{

Locates the implementation of the package specified by @racket[desc]
and downloads and unpacks it to a temporary directory (as needed).

If @racket[desc] refers to an existing directory and
@racket[in-place?] is true, then the directory is used in place.

The @racket[namespace] argument is passed along to
@racket[get-info/full] when the package's @filepath{info.rkt} is
loaded.

If @racket[strip] is not @racket[#f], then files and directories are
removed from the prepared directory the same as when creating the
corresponding kind of package. A directory that is staged in-place
cannot be stripped.

The result is the package name, the directory containing the unpacked package content,
the checksum (if any) for the unpacked package, whether the
directory should be removed after the package content is no longer
needed, and a list of module paths provided by the package.}


@defproc[(pkg-config [set? boolean?] [keys/vals list?])
         void?]{

Implements @racket[pkg-config-command].

The package lock must be held (allowing writes if @racket[set?] is true); see
@racket[with-pkg-lock].}


@defproc[(pkg-create [format (or/c 'zip 'tgz 'plt 'MANIFEST)]
                     [dir path-string?]
                     [#:quiet? quiet? boolean? #f])
        void?]{

Implements @racket[pkg-create-command].

Unless @racket[quiet?] is true, information about the output is repotred to the current output port.}


@defproc[(pkg-install      [descs (listof pkg-desc?)]
                           [#:dep-behavior dep-behavior
                                           (or/c #f 'fail 'force 'search-ask 'search-auto)
                                           #f]
                           [#:update-deps? update-deps? boolean? #f]
                           [#:force? force? boolean? #f]
                           [#:ignore-checksums? ignore-checksums? boolean? #f]
                           [#:quiet? boolean? quiet? #f]
                           [#:strip strip (or/c #f 'source 'binary) #f]
                           [#:link-dirs? link-dirs? boolean? #f])
         (or/c 'skip
               #f
               (listof (or/c path-string?
                             (non-empty-listof path-string?))))]{

Implements @racket[pkg-install-command]. The result indicates which
collections should be setup via @exec{raco setup}: @racket['skip]
means that no setup is needed, @racket[#f] means all, and a list means
only the indicated collections.

The @racket[link-dirs?] argument determines whether package sources
inferred to be directory paths should be treated as links or copied
(like other package sources). Note that the default is @racket[#f],
unlike the default built into @racket[pkg-install-command].

Status information and debugging details are mostly reported to a logger
named @racket['pkg], but information that is especially relevant to a
user (such as a download action) is reported to the current output
port, unless @racket[quiet?] is true.

The package lock must be held; see @racket[with-pkg-lock].}


@defproc[(pkg-update      [names (listof (or/c string? pkg-desc?))]
                          [#:all? all? boolean? #f]
                          [#:dep-behavior dep-behavior
                                          (or/c #f 'fail 'force 'search-ask 'search-auto)
                                          #f]
                          [#:update-deps? update-deps? boolean? #f]
                          [#:force? force? boolean? #f]
                          [#:ignore-checksums? ignore-checksums? boolean? #f]
                          [#:quiet? boolean? quiet? #f]
                          [#:strip strip (or/c #f 'source 'binary) #f]
                          [#:link-dirs? link-dirs? boolean? #f])
        (or/c 'skip
              #f
              (listof (or/c path-string?
                            (non-empty-listof path-string?))))]{

Implements @racket[pkg-update-command]. The result is the same as for
@racket[pkg-install].

A string in @racket[names] refers to an installed package that should
be checked for updates. A @racket[pkg-desc] in @racket[names] indicates
a package source that should replace the current installation.

The package lock must be held; see @racket[with-pkg-lock].}


@defproc[(pkg-remove      [names (listof string?)]
                          [#:demote? demote? boolean? #f]
                          [#:auto? auto? boolean? #f]
                          [#:force? force? boolean? #f]
                          [#:quiet? boolean? quiet? #f])
         (or/c 'skip
               #f
               (listof (or/c path-string? 
                             (non-empty-listof path-string?))))]{

Implements @racket[pkg-remove-command]. The result is the same as for
@racket[pkg-install], indicating collects that should be setup via
@exec{raco setup}.

The package lock must be held; see @racket[with-pkg-lock].}


@defproc[(pkg-show [indent string?]
                   [#:directory show-dir? boolean? #f])
         void?]{

Implements @racket[pkg-show-command] for a single package scope,
printing to the current output port. See also
@racket[installed-pkg-names] and @racket[installed-pkg-table].

The package lock must be held to allow reads; see
@racket[with-pkg-lock/read-only].}


@defproc[(pkg-migrate      [from-version string?]
                           [#:dep-behavior dep-behavior
                                           (or/c #f 'fail 'force 'search-ask 'search-auto)
                                           #f]
                           [#:force? force? boolean? #f]
                           [#:ignore-checksums? ignore-checksums? boolean? #f]
                           [#:quiet? boolean? quiet? #f]
                           [#:strip strip (or/c #f 'source 'binary) #f])
         (or/c 'skip
               #f
               (listof (or/c path-string?
                             (non-empty-listof path-string?))))]{

Implements @racket[pkg-migrate-command].  The result is the same as for
@racket[pkg-install].

The package lock must be held; see @racket[with-pkg-lock].}


@defproc[(pkg-catalog-show [names (listof string?)]
                           [#:all? all? boolean? #f]
                           [#:only-names? only-names? boolean? #f]
                           [#:modules? modules? boolean? #f])
         void?]{

Implements @racket[pkg-catalog-show-command]. If @racket[all?] is true,
then @racket[names] should be empty.

The @racket[current-pkg-scope-version] parameter determines the version
included in the catalog query.}


@defproc[(pkg-catalog-copy [sources (listof path-string?)]
                           [dest path-string?]
                           [#:from-config? from-config? boolean? #f]
                           [#:merge? merge? boolean? #f]
                           [#:force? force? boolean? #f]
                           [#:override? override? boolean? #f])
         void?]{

Implements @racket[pkg-catalog-copy-command].

The @racket[current-pkg-scope-version] parameter determines the version
for extracting existing catalog information.}


@defproc[(pkg-catalog-update-local [#:catalog-file catalog-file path-string? (current-pkg-catalog-file)]
                                   [#:quiet? quiet? boolean? #f]
                                   [#:consult-packages? consult-packages? boolean? #f])
         void?]{

Consults the user's configured @tech{package catalogs} (like
@racket[pkg-catalog-copy]) and package servers (if
@racket[consult-packages?] is true) to populate the database
@racket[catalog-file] with information about available packages and the
modules that they implement.}


@defproc[(pkg-catalog-suggestions-for-module 
          [module-path module-path?]
          [#:catalog-file catalog-file path-string? ....])
         (listof string?)]{

Consults @racket[catalog-file] and returns a list of available packages
that provide the module specified by @racket[module-path].

The default @racket[catalog-file] is @racket[(current-pkg-catalog-file)]
if that file exists, otherwise a file in the racket installation is
tried.}


@defproc[(get-all-pkg-names-from-catalogs) (listof string?)]{

Consults @tech{package catalogs} to obtain a list of available
@tech{package names}.}


@defproc[(get-all-pkg-details-from-catalogs)
         (hash/c string? (hash/c symbol? any/c))]{

Consults @tech{package catalogs} to obtain a hash table of available
@tech{package names} mapped to details about the package. Details for
a particular package are provided by a hash table that maps symbols
such as @racket['source], @racket['checksum], and @racket['author].}


@defproc[(get-pkg-details-from-catalogs [name string?])
         (or/c #f (hash/c symbol? any/c))]{

Consults @tech{package catalogs} to obtain information for a
single @tech{package name}, returning @racket[#f] if the @tech{package
name} has no resolution. Details for the package are provided in the
same form as from @racket[get-all-pkg-details-from-catalogs].}


@defproc[(pkg-single-collection [dir path-string?]
                                [#:name name string? @elem{... from @racket[dir] ...}]
                                [#:namespace namespace namespace? (make-base-namespapce)])
         (or/c #f string?)]{

Returns a string for a collection name if @racket[dir] represents a
@tech{single-collection package}, or returns @racket[#f] if @racket[dir]
represents a @tech{multi-collection package}.

For some single-collection packages, the package's single collection
is the package name; if the package name is different from the
directory name, supply @racket[name].

Determining a single-collection package's collection name may require
loading an @filepath{info.rkt} file, in which case @racket[namespace]
is passed on to @racket[get-info/full].}


@defproc[(get-pkg-content [desc pkg-desc?]
                          [#:extract-info 
                           extract-proc
                           ((or/c #f
                                  ((symbol?) ((-> any)) . ->* . any))
                            . -> . any)
                           (lambda (get-pkg-info) ...)])
         (values (or/c #f string?) 
                 (listof module-path?)
                 any/c)]{

Gets information about the content of the package specified by
@racket[desc]. The information is determined inspecting the
package---resolving a @tech{package name}, downloading, and unpacking
into a temporary directory as necessary.

The results are as follows:

@itemize[

 @item{The checksum, if any, for the downloaded package.}

 @item{A list of module paths that are provided by the package.
       Each module path is normalized in the sense of
       @racket[collapse-module-path].}

 @item{Information extracted from the package's metadata.  By default,
       this information is the package's dependencies, but in general
       it is the result of @racket[extract-proc], which receives an
       information-getting function (or @racket[#f]) as returned by
       @racket[get-info].}

]}

@defproc[(extract-pkg-dependencies [info (symbol? (-> any/c) . -> . any/c)]
                                   [#:build-deps? build-deps? boolean? #f]
                                   [#:filter? filter? boolean? #f])
         (listof (or/c string? (cons/c string? list?)))]{

Returns packages dependencies reported by the @racket[info] procedure
(normally produced by @racket[get-info]).

If @racket[build-deps?] is true, then the result includes both
run-time dependencies and build-time dependencies.

If @racket[filter?] is true, then platform-specific dependencies are
removed from the result list when they do not apply to the current
platform, and other information is stripped so that the result list is
always a list of strings.}

@defproc[(pkg-directory->module-paths [dir path-string?]
                                      [pkg-name string]
                                      [#:namespace namespace namespace? (make-base-namespace)])
         (listof module-path?)]{

Returns a list of module paths (normalized in the sense of
@racket[collapse-module-path]) that are provided by the package
represented by @racket[dir] and named @racket[pkg-name].}
