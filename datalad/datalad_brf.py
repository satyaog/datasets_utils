import glob
import inspect
from os.path import basename, join, splitext
import subprocess
import sys

from datalad import coreapi
from datalad.config import ConfigManager
from datalad.support.exceptions import IncompleteResultsError

GITHUB_REPO_PREFIX = "git@github.com"
GITHUB_REPO_API = "https://api.github.com/user/repos"


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
        name = _strip_git(url)

    install_subdatasets_tree(url, sibling)
    coreapi.install(name, source=(None if url == name else url),
                    recursive=recursive)

    if sibling == "github":
        reponame = _get_github_reponame(".", name)
        init_github(reponame, dataset=name, sibling=sibling)


def install_subdatasets_tree(url, sibling="origin"):
    url = url.rstrip('/')

    super_ds = coreapi.Dataset(path=".")
    subdatasets = [sub_ds["gitmodule_name"] for sub_ds in super_ds.subdatasets()]
    for sub_ds in subdatasets:
        if url.startswith(sub_ds):
            break
    else:
        return False

    dataset_path = "."
    while url:
        dataset = coreapi.Dataset(path=dataset_path)
        subdatasets = [sub_ds["gitmodule_name"] for sub_ds in dataset.subdatasets()]
        for sub_ds in subdatasets:
            if url.startswith(sub_ds):
                url = url[len(sub_ds):].lstrip('/')
                name = sub_ds
                break
        else:
            break

        try:
            coreapi.install(path=join(dataset_path, name), dataset=dataset,
                on_failure="stop")
        except IncompleteResultsError as error:
            github_sibling = next(iter(dataset.siblings(name="github")), None)
            if github_sibling:
                path = join(dataset_path, name)
                source = "--".join([_strip_git(github_sibling["url"]), name + ".git"])
                coreapi.install(path=path, dataset=dataset, source=source)
                coreapi.siblings("add", dataset=path, name="github", url=source)
                coreapi.siblings("remove", dataset=path, name="origin")
            else:
                raise error

        dataset_path = join(dataset_path, name)

    return True


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


def init_github(name=None, login=None, token=None, dataset=".", sibling="github"):
    if name is None:
        name = _get_github_reponame(dataset)

    dataset = coreapi.Dataset(path=dataset)

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

    repository = join("{}:{}".format(GITHUB_REPO_PREFIX, login), name) + ".git"
    coreapi.siblings("configure", dataset=dataset, name=sibling, url=repository,
                     publish_by_default="master")
    dataset.config.set("remote.{}.annex-ignore".format(sibling), "true",
                       where="local")

    subprocess.run(["curl", "-i", "-H", f"Authorization: token {token}",
                    "-d", str({"name":name, "default_branch":"master"}).replace("'", "\""),
                    GITHUB_REPO_API])
    # push master first to flag it as the default branch
    subprocess.run(["git", "-C", dataset.path, "push", sibling, "master"])
    subprocess.run(["git", "-C", dataset.path, "push", sibling, "git-annex", "+refs/heads/var/*"])
    subprocess.run(["git", "-C", dataset.path, "push", sibling, "--tags"])
    dataset.publish(to=sibling)


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
