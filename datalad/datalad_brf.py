import glob
import inspect
from os.path import basename, dirname, join, splitext
import subprocess
import sys

from datalad import coreapi
from datalad.config import ConfigManager
from datalad.support.exceptions import IncompleteResultsError

GITHUB_REPO_PREFIX = "git@github.com"
GITHUB_REPO_PREFIX_HTTP = "https://github.com"
GITHUB_API = "https://api.github.com"
GITHUB_API_CREATE_REPO = f"{GITHUB_API}/user/repos"
GITHUB_API_UPDATE_REPO = GITHUB_API + "/repos/{owner}/{repo}"


def _strip_git(url):
    name, ext = splitext(url)
    if ext != ".git":
        name += ext
    return name


def _get_github_reponame(dataset_path, name=""):
    if "github.com" in name:
        return _strip_git(basename(name.split('/')[-1]))

    dataset = coreapi.Dataset(path=dataset_path)
    ds_name = None
    ds_path = dataset.path.split('/')

    reponame_buffer = name.split('/')
    tmp_buf = []

    while dataset.id is not None:
        tmp_buf.extend(reponame_buffer)
        reponame_buffer = tmp_buf
        tmp_buf = []

        for s in dataset.siblings():
            if s["name"] == "origin":
                ds_name = _strip_git(basename(s["url"]))
            elif s["name"] == "github":
                ds_name = _strip_git(basename(s["url"]))
                # Stop iteration at the end of this step
                ds_path = []
                dataset = coreapi.Dataset(path="__stop__")
                break

        if not ds_name:
            ds_name = basename(dataset.path)

        reponame_buffer.insert(0, ds_name)
        ds_name = None
        while '/'.join(ds_path[:-1]):
            ds_path.pop()
            dataset = coreapi.Dataset(path='/'.join(ds_path))
            tmp_buf.insert(0, ds_path[-1])
            if dataset.id is not None:
                # Skip current dataset name
                tmp_buf = tmp_buf[1:]
                break

    return "--".join(reponame_buffer).strip("--")


def create(name, sibling="origin"):
    super_ds = coreapi.Dataset(path=".")
    coreapi.create(path=name, dataset=super_ds if super_ds.id else None)

    if sibling == "github":
        reponame = _get_github_reponame(".", name)
        init_github(reponame, dataset=name, sibling=sibling)


def install(url, name=None, sibling="origin", recursive=False):
    url = url.rstrip('/')
    if name is None:
        if any(url.startswith(p) for p in ("http:", "https:", "git@")):
            name = basename(url)
        else:
            name = url
        name = _strip_git(name)

    if not install_subdatasets_tree(url, recursive=recursive):
        coreapi.install(name, source=(None if url == name else url),
                        recursive=recursive)

    if any(url.startswith(p) for p in (GITHUB_REPO_PREFIX,
                                       GITHUB_REPO_PREFIX_HTTP)):
        sibling = "github"

        origin_sibling = None
        gh_sibling = None
        for s in coreapi.Dataset(path=name).siblings():
            if s["name"] == "origin":
                origin_sibling = s["url"]
            elif s["name"] == "github":
                gh_sibling = s["url"]
        if gh_sibling is None:
            coreapi.siblings("add", dataset=name, name=sibling, url=url)
            gh_sibling = url
        if origin_sibling == gh_sibling:
            coreapi.siblings("remove", dataset=name, name="origin")

    if sibling == "github":
        reponame = _get_github_reponame(name)
        init_github(reponame, dataset=name, sibling=sibling)


def install_subdatasets_tree(url, recursive=False):
    url = url.rstrip('/')
    _url = url

    super_ds = coreapi.Dataset(path=".")
    subdatasets = [subds["gitmodule_name"] for subds in super_ds.subdatasets()]
    for subds in subdatasets:
        if url.startswith(subds):
            break
    else:
        return False

    dataset_path = "."
    while url:
        dataset = coreapi.Dataset(path=dataset_path)
        subdatasets = [subds["gitmodule_name"] for subds in dataset.subdatasets()]
        for subds in subdatasets:
            if url.startswith(subds):
                url = url[len(subds):].lstrip('/')
                name = subds
                break
        else:
            break

        try:
            coreapi.install(path=join(dataset_path, name), dataset=dataset,
                on_failure="stop")
        except IncompleteResultsError:
            gh_sibling = next(iter(dataset.siblings(name="github")), None)
            if gh_sibling:
                path = join(dataset_path, name)
                source = (dirname(_strip_git(gh_sibling["url"])),
                          _get_github_reponame(dataset_path, name) + ".git")
                source = "/".join(source)
                coreapi.install(path=path, dataset=dataset, source=source)
                coreapi.siblings("add", dataset=path, name="github", url=source)
                coreapi.siblings("remove", dataset=path, name="origin")
            else:
                raise

        dataset_path = join(dataset_path, name)
    else:
        if recursive:
            dataset = coreapi.Dataset(path=dataset_path)
            subdatasets = [subds["gitmodule_name"]
                           for subds in dataset.subdatasets()]
            for subds in subdatasets:
                install_subdatasets_tree(join(_url, subds), recursive=recursive)

    return not url


def install_subdatasets(sibling="origin"):
    coreapi.install(path=".", recursive=True)
    reponame = _get_github_reponame(".")
    if sibling == "github":
        init_github(reponame, dataset=".", sibling=sibling)


def publish(path="*", sibling="origin"):
    coreapi.add(path=glob.glob(path), recursive=True)
    coreapi.save()
    coreapi.publish(to=sibling, recursive=True, missing="skip")


def update(sibling="origin"):
    coreapi.update(sibling=sibling, recursive=True, merge=True)


def _init_gh_config(dataset, login=None, token=None):
    login_config = dataset.config.get("datalad.github.username")
    if login is None:
        login = login_config
    if login_config is None:
        dataset.config.set("datalad.github.username", login, where="global")

    token_config = dataset.config.get("datalad.github.oauthtoken")
    if token is None:
        token = token_config
    assert token is not None
    if token_config is None:
        dataset.config.set("datalad.github.oauthtoken", token, where="global")

    return login, token


def init_github(name=None, login=None, token=None, dataset=".", sibling="github"):
    if name is None:
        name = _get_github_reponame(dataset)

    dataset = coreapi.Dataset(path=dataset)

    # token requires `repo/public_repo` scope authorization
    login, token = _init_gh_config(dataset, login, token)

    repository = join(f"{GITHUB_REPO_PREFIX}:{login}", name) + ".git"
    coreapi.siblings("configure", dataset=dataset, name=sibling, url=repository,
                     publish_by_default="master")
    dataset.config.set("remote.{}.annex-ignore".format(sibling), "true",
                       where="local")

    subprocess.run(["curl", "-i", "-H", f"Authorization: token {token}",
                    "-d", str({"name":name}).replace("'", "\""),
                    GITHUB_API_CREATE_REPO])
    subprocess.run(["git", "-C", dataset.path, "push", sibling,
                    "master", "git-annex", "+refs/heads/var/*"])
    subprocess.run(["git", "-C", dataset.path, "push", sibling, "--tags"])
    # Set default branch to master
    subprocess.run(["curl", "-i", "-H", f"Authorization: token {token}",
                    "-d", str({"name":name,"default_branch":"master"}).replace("'", "\""),
                    GITHUB_API_UPDATE_REPO.format(owner=login, repo=name)])


def del_github(name=None, login=None, token=None, dataset=".", sibling="github"):
    if name is None:
        name = _get_github_reponame(dataset)

    dataset = coreapi.Dataset(path=dataset)

    # token requires `delete_repo` scope authorization
    login, token = _init_gh_config(dataset, login, token)

    coreapi.siblings("remove", dataset=dataset, name=sibling)
    subprocess.run(["curl", "-X", "DELETE", "-H", f"Authorization: token {token}",
                    GITHUB_API_UPDATE_REPO.format(owner=login, repo=name)])


if __name__ == "__main__":
    # get the second argument from the command line
    fct_name = sys.argv[1]

    # get pointers to the objects based on the string names
    fct = globals()[fct_name]

    # pass all the parameters from the third until the end of
    # what the function needs & ignore the rest
    args = inspect.getargspec(fct)
    params = sys.argv[2:len(args[0]) + 2]
    params = {p:v for p,v in (p.split("=") for p in params) if v}
    fct(**params)
